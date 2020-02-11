//
//  HotViewController.swift
//  Ruisi
//
//  Created by yang on 2017/4/18.
//  Copyright © 2017年 yang. All rights reserved.
//

import UIKit
import Kanna

// 首页 - 热帖/新帖
class HotViewController: BaseTableViewController<ArticleListData>,ScrollTopable,UIViewControllerPreviewingDelegate {

    private var initContentOffset: CGFloat = 0.0
    
    override func viewDidLoad() {
        self.autoRowHeight = false
        self.showRefreshControl = true
        super.viewDidLoad()
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        initContentOffset = self.tableView.contentOffset.y
    }
    
    // 切换热帖0 和 新帖1
    @IBAction func viewTypeChnage(_ sender: UISegmentedControl) {
        position = sender.selectedSegmentIndex
        self.isLoading = false
        self.datas = []
        self.tableView.reloadData()
        self.rsRefreshControl?.beginRefreshing()
        reloadData()
    }
    
    func scrollTop() {
        print("scrollTop")
        if self.tableView?.contentOffset.y ?? initContentOffset > initContentOffset {
            self.tableView?.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        } else if !isLoading {
            self.datas = []
            self.tableView.reloadData()
            self.rsRefreshControl?.beginRefreshing()
            reloadData()
        }
    }
    
    var isHotLoading = false
    var isNewLoading = false
    override var isLoading: Bool {
        get {
            if position == 0 {
                return isHotLoading
            } else {
                return isNewLoading
            }
        }
        
        set {
            if position == 0 {
                isHotLoading = newValue
            } else {
                isNewLoading = newValue
            }
            super.isLoading = newValue
        }
    }
    
    
    override func getUrl(page: Int) -> String {
        if position == 0 {
            return Urls.hotUrl + "&page=\(currentPage)"
        } else {
            return Urls.newUrl + "&page=\(currentPage)"
        }
    }
    
    override func parseData(pos: Int, doc: HTMLDocument) -> [ArticleListData] {
        currentPage = Int(doc.xpath("/html/body/div[2]/strong").first?.text ?? "") ?? currentPage
        totalPage = Utils.getNum(from: (doc.xpath("/html/body/div[2]/label/span").first?.text) ?? "") ?? currentPage
        var subDatas: [ArticleListData] = []
        for li in doc.css(".threadlist ul li") {
            let a = li.css("a").first
            var tid: Int?
            if let u = a?["href"] {
                tid = Utils.getNum(from: u)
            } else {
                //没有tid和咸鱼有什么区别
                continue
            }
            
            var replysStr: String?
            var authorStr: String?
            let replys = li.css("span.num").first
            let author = li.css(".by").first
            if let r = replys {
                replysStr = r.text
                a?.removeChild(r)
            }
            if let au = author {
                authorStr = au.text
                a?.removeChild(au)
            }
            let img = (li.css("img").first)?["src"]
            var haveImg = false
            if let i = img {
                haveImg = i.contains("icon_tu.png")
            }
            
            let title = a?.text?.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n "))
            let color = Utils.getHtmlColor(from: a?["style"])
            let d = ArticleListData(title: title ?? "未获取到标题", tid: tid!, author: authorStr ?? "未知作者", replys: replysStr ?? "0", read: false, haveImage: haveImg, titleColor: color)
            d.rowHeight = caculateRowheight(isSchoolNet: false, width: self.tableViewWidth, title: d.title)
            subDatas.append(d)
        }
        
        //从浏览历史数据库读出是否已读
        SQLiteDatabase.instance?.setReadHistory(datas: &subDatas)
        return subDatas
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        _ = super.numberOfSections(in: tableView)
        if datas.count == 0 && !isLoading {//no data avaliable
            let title = "暂无内容"
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.bounds.height))
            label.text = title
            label.numberOfLines = 0
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 20)
            if #available(iOS 13.0, *) {
                label.textColor = UIColor.placeholderText
            } else {
                label.textColor = UIColor.lightGray
            }
            label.sizeToFit()
            
            tableView.backgroundView = label
            tableView.separatorStyle = .none
            
            return 0
        } else {
            tableView.backgroundView = nil
            tableView.separatorStyle = .singleLine
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let titleLabel = cell.viewWithTag(1) as! UILabel
        let usernameLabel = cell.viewWithTag(2) as! UILabel
        let commentsLabel = cell.viewWithTag(3) as! UILabel
        let haveImageLabel = cell.viewWithTag(4) as! UILabel
        let d = datas[indexPath.row]
        
        titleLabel.text = d.title
        if d.isRead {
            if #available(iOS 13.0, *) {
                titleLabel.textColor = UIColor.secondaryLabel
            } else {
                titleLabel.textColor = UIColor.darkGray
            }
        } else if let color = d.titleColor {
            titleLabel.textColor = color
        } else {
            if #available(iOS 13.0, *) {
                titleLabel.textColor = UIColor.label
            } else {
                titleLabel.textColor = UIColor.darkText
            }
        }
        usernameLabel.text = d.author
        commentsLabel.text = d.replyCount
        haveImageLabel.isHidden = !d.haveImage
        
        //forceTouch
        if traitCollection.forceTouchCapability == .available {
            registerForPreviewing(with: self, sourceView: cell)
        }
        
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        
        if (!datas[indexPath.row].isRead) { // 未读设置为已读
            datas[indexPath.row].isRead = true
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let d = datas[indexPath.row]
        return d.rowHeight
    }
    
    // 计算行高
    private func caculateRowheight(isSchoolNet: Bool, width: CGFloat, title: String) -> CGFloat {
        let titleHeight = title.height(for: width - 32, font: UIFont.systemFont(ofSize: 16, weight: .medium))
        // 上间距(12) + 正文(计算) + 间距(8) + 昵称(14.5) + 下间距(10)
        return 12 + titleHeight + 8 + 14.5 + 10
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let dest = segue.destination as? PostViewController,
            let cell = sender as? UITableViewCell {
            let index = tableView.indexPath(for: cell)!
            dest.title = datas[index.row].title
            dest.tid = datas[index.row].tid
        }
    }
    
    // MARK -- 3D touch
    var peekedVc: UIViewController?
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let cell = previewingContext.sourceView as? UITableViewCell, let index = self.tableView?.indexPath(for:cell ) {
            let peekVc = storyboard?.instantiateViewController(withIdentifier: "PostViewController") as! PostViewController
            
            peekVc.title = datas[index.row].title
            peekVc.tid = datas[index.row].tid
            
            peekVc.preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            self.peekedVc = peekVc
            return peekVc
        }
        
        peekedVc = nil
        return nil
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let vc = self.peekedVc {
            self.show(vc, sender: self)
        }
    }
}
