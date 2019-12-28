//
//  RitchTextView.swift
//  SmileyView
//
//  Created by yang on 2017/12/21.
//  Copyright © 2017年 yang. All rights reserved.
//

import UIKit

class RitchTextView: UITextView {
    
    lazy var smileyView: SmileyView = SmileyView.smileyView()
    lazy var toolbarView: ToolbarView = ToolbarView.toolbarView()
    lazy var placeholderLabel: UILabel = UILabel()
    
    public weak var context: UIViewController?
    
    public var showToolbar: Bool = false {
        didSet{
            if showToolbar {
                self.inputAccessoryView = self.toolbarView
                setUpToolbarView()
            } else {
                self.inputAccessoryView = nil
            }
        }
    }
    
    public var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
        }
    }
    
    override var text: String! {
        didSet {
            textChnage()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        print("RitchTextView")
        setUpPlaceholder()
        setUpToolbarView()
    }
    
    var placeTextColor: UIColor {
        if #available(iOS 13.0, *) {
            return UIColor.placeholderText
        } else {
            return UIColor.lightGray
        }
    }
    
    private func setUpPlaceholder() {
        placeholderLabel.font = font
        placeholderLabel.textColor = placeTextColor
        placeholderLabel.sizeToFit()
        placeholderLabel.frame = CGRect(x: 5, y: 8, width: 100, height: 15)
        
        addSubview(placeholderLabel)
        
        NotificationCenter.default.addObserver(self, selector: #selector(textChnage), name: UITextView.textDidChangeNotification, object: nil)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.frame = CGRect(x: 5, y: 8, width: frame.width - 10, height: 15)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextView.textDidChangeNotification, object: nil)
    }
    
    @objc func textChnage(_ notification: Notification? = nil) {
        placeholderLabel.isHidden = hasText || (self.result?.count ?? 0) > 0
    }
    
    private func setUpToolbarView() {
        if !showToolbar { return }

        toolbarView.onAtClick {[weak self] (btn) in
            let dest = self?.context?.storyboard?.instantiateViewController(withIdentifier: "chooseFriendViewNavigtion") as! UINavigationController
            if let vc = dest.topViewController as? ChooseFriendViewController {
                vc.delegate = { names in // 选择过后调用
                    print(names)
                    var result: String = ""
                    names.forEach { (name) in
                        result += " @\(name)"
                    }
                    if names.count > 0 {
                        result += " "
                    }
                    
                    self?.insertText(result)
                }
                self?.context?.present(dest, animated: true, completion: nil)
            }
        }
        
        toolbarView.onToggleSmiley {[weak self] (btn) in
            self?.toggleEmojiInput()
        }
        
        toolbarView.onHideKeyboardClick {[weak self] (btn) in
            self?.inputView = nil
            self?.resignFirstResponder()
        }
    }
    
    // 获得纯文本，图片 表情 已经转化为字符串
    public var result: String? {
        guard let attrStr = attributedText else { return nil }
        
        var result = String()
        attrStr.enumerateAttributes(in: NSRange(location: 0, length: attrStr.length), options: []) { (dict, range, _) in
            if let attach = dict[NSAttributedString.Key.attachment] as? ImageAttachment {
                if let v = attach.value {
                    result += v
                }
            }else {
                result += (attrStr.string as NSString).substring(with: range)
            }
        }
        return result
    }
    
    
    // 显示隐藏表情键盘
    public func toggleEmojiInput() {
        if inputView == nil {
            inputView =  smileyView
            smileyView.smileyClick = { [weak self] item in
                if let smiley = item {
                    if smiley.image != nil { //插入表情
                        self?.insertImageText(imageText: smiley.imageText(font: self?.font ?? UIFont.systemFont(ofSize: 15)))
                    } else if let select = self?.selectedTextRange{ // 插入文字
                        self?.replace(select, withText: " " + smiley.value)
                    }
                }else {
                    self?.deleteBackward()
                }
            }
        }else {
            inputView = nil
        }
        
        reloadInputViews()
    }
    
    // 插入图片最大宽度不超过view的宽度
    func inserImage(image: UIImage, aid: Int) {
        let attrStr = NSMutableAttributedString()
        let attach =  ImageAttachment()
        //discuz 插入图片写法
        attach.value = " [attachimg]\(aid)[/attachimg] "
        attach.image = image
        let width = min(image.size.width, frame.width)
        let height = (width / image.size.width) * image.size.height
        
        attach.bounds = CGRect(x: 0, y: 0, width:  width, height: height)
        
        //添加font属性防止字体变小
        attrStr.addAttributes([NSAttributedString.Key.attachment : attach,NSAttributedString.Key.font: font ?? UIFont.systemFont(ofSize: 15)],range: NSRange(location: 0, length: 1))
        insertImageText(imageText: attrStr)
        
        //手冻执行代理
        delegate?.textViewDidChange?(self)
        self.textChnage()
    }
    
    
    // 插入image属性文本
    func insertImageText(imageText: NSAttributedString) {
        let range = selectedRange
        
        let attrString = NSMutableAttributedString(attributedString: attributedText)
        attrString.replaceCharacters(in: range, with: imageText)
        attributedText = attrString
        
        //重新设置光标的位置
        selectedRange = NSRange(location: range.location + 1, length: 0)
        
        //手冻执行代理
        delegate?.textViewDidChange?(self)
        self.textChnage()
    }
}
