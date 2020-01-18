//
//  ForumsController.swift
//  Ruisi
//
//  Created by yang on 2017/4/17.
//  Copyright © 2017年 yang. All rights reserved.
//

import UIKit
import Kanna

// 首页 - 板块列表
class ForumsViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ScrollTopable {
    
    private var datas: [Forums] = [] {
        didSet {
            if !Settings.closeRecentVistForum && recentFids.count > 0 {
                let fs = Forums(gid: 0, name: "最近常逛", login: false, canPost: true)
                var ffs = [Forum]()
                for recentFid in recentFids {
                    for item in datas {
                        if let ff = item.findForum(fid: recentFid) {
                            ffs.append(ff)
                            break
                        }
                    }
                    
                    if ffs.count == (type == 0 ? colCount : colCount * 2) {
                        break
                    }
                }
                
                if ffs.count > 0 {
                    fs.forums = ffs
                    datas.insert(fs, at: 0)
                }
            }
        }
    }
    private var colCount: Int { //collectionView列数
        if type == 0 {
            return min(UIDevice.current.orientation.isLandscape ? 12 : 9, Int(UIScreen.main.bounds.width / 75))
        } else {
            return min(UIDevice.current.orientation.isLandscape ? 5 : 4, Int(UIScreen.main.bounds.width / 135))
        }
    }
    private var type = 1 // 0-grid显示 1-列表显示
    
    var loadedUid: Int?
    var loaded = false
    var recentFids = [Int]()
    
    private var isWrhr: Bool {
        return traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .regular
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        self.clearsSelectionOnViewWillAppear = true
        type = Settings.forumListDisplayType ?? 1
        
        if !Settings.closeRecentVistForum, let fids = SQLiteDatabase.instance?.loadRecentVisitForums(count: 10) {
            recentFids.append(contentsOf: fids)
        }
    }
    
    func scrollTop() {
        self.collectionView?.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
    }
    
    public func networkChange() {
        if !(Network.reachability?.isConnectedToNetwork ?? false) {
            if !(self.title?.contains("未连接") ?? false) {
                self.title = self.title! + "(未连接)"
            }
        } else {
            if self.title?.contains("未连接") ?? false {
                self.title = String(self.title![self.title!.startIndex ..< self.title!.range(of: "(未连接)")!.lowerBound])
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if loadedUid != (Settings.uid ?? 0) {
            loadData(uid: Settings.uid)
        }
    }
    
    @IBAction func switchDisplayTypeClick(_ sender: UIBarButtonItem) {
        if type == 0 {
            type = 1
        } else {
            type = 0
        }
        
        Settings.forumListDisplayType = type
        self.collectionView?.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.collectionView?.reloadData()
    }

    
    // uid == nil 加载未登录的
    private func loadData(uid: Int?) {
        loadedUid = (Settings.uid ?? 0)
        print("====================")
        print("加载板块列表:\(loadedUid!)")
        
        let day = Int(Date().timeIntervalSince1970 / 86400) - Settings.getFormlistSavedTime(uid: uid)
        if day < 7, let d = Settings.getForumlist(uid: uid), let ds = try? JSONDecoder().decode([Forums].self, from: d) {
            //不用过滤
            datas = ds
            loaded = true
            print("从保存的设置里面 读取板块列表 uid:\(uid ?? 0)")
            collectionView?.reloadData()
        } else {
            loaded = false
            print("缓存过期\(day)，从网页读取板块列表: \(App.isSchoolNet)")
            print("开始从网页读取板块列表")
            loadDeafultForum()
            loadFormlistFromWeb()
        }
    }
    
    private func loadDeafultForum() {
        print("临时使用forums.json板块列表")
        let filePath = Bundle.main.path(forResource: "assets/forums", ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: filePath, isDirectory: false))
        datas = try! JSONDecoder().decode([Forums].self, from: data).filter({ (f) -> Bool in
            f.forums = f.forums?.filter({ (ff) -> Bool in
                return (Settings.uid != nil) || !ff.login
            })
            return (Settings.uid != nil) || !f.login
        })
        collectionView?.reloadData()
    }
    
    private func loadFormlistFromWeb() {
        HttpUtil.GET(url: Urls.forumlistUrl, params: nil) { [weak self] (ok, res) in
            guard ok else { return }
            if let html = try? HTML(html: res, encoding: .utf8) {
                var uid: Int?
                if let userNode = html.xpath("//*[@id=\"usermsg\"]/a").first {
                    uid = Utils.getNum(prefix: "uid=", from: userNode["href"]!)
                }
                var forumCount = 0
                let groups = html.xpath("//*[@id=\"wp\"]/div")
                var listForms = [Forums]()
                for group in groups {
                    if let groupName = group.xpath(".//h2/a").first?.text {
                        let items = group.xpath(".//a")
                        var forms = [Forum]()
                        for item in items {
                            if let fid = Utils.getNum(prefix: "fid=", from: item["href"]!) {
                                var new: Int?
                                if let numNode = item.xpath("span").first {
                                    new = Utils.getNum(from: numNode.text!)
                                    item.removeChild(numNode)
                                }
                                
                                let f = Forum(fid: fid, name: item.text!, login: false)
                                f.new = new
                                
                                forumCount += 1
                                forms.append(f)
                            }
                        }
                        
                        let formss = Forums(gid: 0, name: groupName, login: false, canPost: true)
                        formss.forums = forms
                        
                        listForms.append(formss)
                    }
                }
                
                DispatchQueue.main.async {
                    self?.datas = listForms
                    self?.loadedUid = uid
                    self?.loaded = true
                    self?.collectionView?.reloadData()
                }
                
                print("从网页加载板块列表完成 登录:\(App.isLogin) uid:\(uid ?? 0) 设置里的uid:\(Settings.uid ?? 0)")
                if let d = try? JSONEncoder().encode(listForms) {
                    Settings.setForumlist(uid: uid, data: d)
                    print("板块列表保存完毕")
                }

                if forumCount <= 5 && !App.isLogin {
                    DispatchQueue.main.async { [weak self] in
                        if let this = self {
                            this.showLoginAlert(message: "你可能需要登录才能查看更多板块！", success: {
                                this.loadFormlistFromWeb()
                            })
                        }
                        
                    }
                }
            }
        }
    }
    
    // 点击头像
    @objc func tapHandler(sender: UITapGestureRecognizer) {
        if App.isLogin {
            self.performSegue(withIdentifier: "myProvileSegue", sender: nil)
        } else {
            //login
            let dest = self.storyboard?.instantiateViewController(withIdentifier: "loginViewNavigtion")
            self.present(dest!, animated: true, completion: nil)
        }
    }
    
    
    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return datas.count
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    //单元格大小
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if type == 0 {
            let cellSize = (collectionView.frame.width - CGFloat((colCount - 1) * 5) - CGFloat(isWrhr ? 32 : 16)) / CGFloat(colCount)
            return CGSize(width: cellSize, height: cellSize + UIFont.systemFont(ofSize: 12).lineHeight - 6)
        } else {
            let cellSize = (collectionView.frame.width - CGFloat(isWrhr ? 32 : 16)) / CGFloat(colCount)
            return CGSize(width: cellSize, height: 56)
        }
    }
    
    // collectionView的上下左右间距    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 5, left: isWrhr ? 16 : 8, bottom: 5, right: isWrhr ? 16 : 8)
    }
    
    
    // 单元的行间距    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return (type == 0) ? 5 : (isWrhr ? 10 : 0)
    }
    
    
    // 每个小单元的列间距
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return (type == 0) ? 5 : 0
    }
    
    // 是否能变色
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // 变色
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let bg = collectionView.cellForItem(at: indexPath)?.backgroundColor
        collectionView.cellForItem(at: indexPath)?.backgroundColor = bg?.withAlphaComponent(0.05)
    }
    
    //结束变色
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        collectionView.cellForItem(at: indexPath)?.backgroundColor = UIColor.clear
    }
    
    // 修复头部在滚动条下面
    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        view.layer.zPosition = 0.0
    }
    
    // section 头或者尾部
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let head = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "head", for: indexPath)
            let label = head.viewWithTag(1) as! UILabel
            label.text = datas[indexPath.section].name
            label.textColor = ThemeManager.currentTintColor
            return head
        }
        
        return UICollectionReusableView(frame: CGRect.zero)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datas[section].getSize()
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: (type == 0) ? "grid_cell" : "list_cell", for: indexPath)
        let imageView = cell.viewWithTag(1) as! UIImageView
        let label = cell.viewWithTag(2) as! UILabel
        let countLabel = cell.viewWithTag(3) as? UILabel
        let fid = datas[indexPath.section].forums![indexPath.row].fid
        if let path = Bundle.main.path(forResource: "common_\(fid)_icon", ofType: "gif", inDirectory: "assets/forumlogo/") {
            imageView.image = UIImage(contentsOfFile: path)
        } else {
            let r = URL(string: "\(Urls.baseUrl)data/attachment/common/cc/common_\(fid)_icon.gif?mobile=2")
            imageView.kf.setImage(with:  r, placeholder: #imageLiteral(resourceName: "placeholder"))
        }
        
        label.text = datas[indexPath.section].forums![indexPath.row].name
        countLabel?.textColor = ThemeManager.currentPrimaryColor
        if let count = datas[indexPath.section].forums![indexPath.row].new, count > 0 {
            countLabel?.text = "+\(count)"
        } else {
            countLabel?.text = ""
        }
        return cell
    }
    
    var selectedIndexPath: IndexPath?
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndexPath = indexPath
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let fid = datas[indexPath.section].forums![indexPath.row].fid
        let type = Urls.getPostsType(fid: fid, isSchoolNet: App.isSchoolNet)
        switch type {
        case .imageGrid:
            self.performSegue(withIdentifier: "forumToImagePosts", sender: self)
        default:
            self.performSegue(withIdentifier: "forumToNormalPosts", sender: self)
        }
        
        if !Settings.closeRecentVistForum {
            DispatchQueue.global(qos: .userInitiated).async {
                SQLiteDatabase.instance?.addVisitFormLog(fid: fid)
            }
        }
    }
    
    
    // MARK: UICollectionViewDelegate
    func showLoginAlert() {
        let alert = UIAlertController(title: "需要登录", message: "你需要登录才能执行此操作", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "登录", style: .default, handler: { (alert) in
            let dest = self.storyboard?.instantiateViewController(withIdentifier: "loginViewNavigtion")
            self.present(dest!, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "formToSearchSegue" {
            if !App.isLogin {
                showLoginAlert()
                return false
            }
        }
        return true
    }
    
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let index = selectedIndexPath {
            let fid = datas[index.section].forums?[index.row].fid
            let title = datas[index.section].forums?[index.row].name
            
            if let dest = (segue.destination as? PostsViewController) {
                dest.title = title
                dest.fid = fid
            } else if let dest = (segue.destination as? ImageGridPostsViewController) {
                dest.title = title
                dest.fid = fid
            }
        }
    }
    
}
