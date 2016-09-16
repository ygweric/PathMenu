//
//  PathMenu.swift
//  PathMenu
//
//  Created by pixyzehn on 12/27/14.
//  Copyright (c) 2014 pixyzehn. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol PathMenuDelegate: class {
    @objc optional func pathMenu(_ menu: PathMenu, didSelectIndex idx: Int)
    @objc optional func pathMenuDidFinishAnimationClose(_ menu: PathMenu)
    @objc optional func pathMenuDidFinishAnimationOpen(_ menu: PathMenu)
    @objc optional func pathMenuWillAnimateOpen(_ menu: PathMenu)
    @objc optional func pathMenuWillAnimateClose(_ menu: PathMenu)
}

open class PathMenu: UIView, PathMenuItemDelegate, CAAnimationDelegate {
    
    struct Radius {
        static var Near: CGFloat = 110.0
        static var End: CGFloat  = 120.0
        static var Far: CGFloat  = 140.0
    }
    
    struct Distance {
        static let UpDiff: CGFloat = 30
        static let DownDiff: CGFloat = 10
        
    }
    
    struct Duration {
        static var DefaultAnimation: CGFloat      = 0.5
        static var ExpandRotateAnimation: CGFloat = 2.0
        static var CloseRotateAnimation: CGFloat  = 1.0
        static var MenuDefaultAnimation: CGFloat  = 0.2
    }
    
    struct Angle {
        static var DefaultRotation: CGFloat   = 0.0
        static var MenuWholeRotation: CGFloat = CGFloat(M_PI * 2)
        static var ExpandRotation: CGFloat    = -CGFloat(M_PI * 2)
        static var CloseRotation: CGFloat     = CGFloat(M_PI * 2)
    }
   
    public enum State {
        case close
        case expand
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience public init(frame: CGRect!, itemSize: CGFloat!, startItem: PathMenuItem?, items:[PathMenuItem]?) {
        self.init(frame: frame)
        self.timeOffset = 0.036
        
        self.itemSize = itemSize
        self.nearRadius = Radius.Near
        self.endRadius  = Radius.End
        self.farRadius  = Radius.Far

        self.animationDuration             = Duration.DefaultAnimation
        self.expandRotateAnimationDuration = Duration.DefaultAnimation
        self.closeRotateAnimationDuration  = Duration.CloseRotateAnimation
        self.startMenuAnimationDuration    = Duration.MenuDefaultAnimation

        self.rotateAngle    = Angle.DefaultRotation
        self.menuWholeAngle = Angle.MenuWholeRotation
        self.expandRotation = Angle.ExpandRotation
        self.closeRotation  = Angle.CloseRotation

        self.startPoint = CGPoint(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2)
 
        self.menuItems = items ?? []
        self.motionState = .close
        
        self.startButton = startItem
        self.startButton!.delegate = self
        self.startButton!.center = startPoint
        self.addSubview(startButton!)
        
        self.startButton?.frame = CGRect(x: (self.startButton?.frame.origin.x)!, y: (self.startButton?.frame.origin.y)!, width: itemSize, height: itemSize)
        for item in menuItems {
            item.frame = CGRect(x: (item.frame.origin.x), y: (item.frame.origin.y), width: itemSize, height: itemSize)
        }
    }

    deinit{
        self.removeObserver(self, forKeyPath: "frame")
    }
    
    open override func willMove(toSuperview newSuperview: UIView?) {
         newSuperview!.addObserver(self, forKeyPath: "frame", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (object as? UIView) == self.superview && keyPath == "frame" {
            self.startPoint = startPointBlock()
        }
    }
    
    open var menuItems: [PathMenuItem] = [] {
        didSet {
            for view in subviews {
                if view.tag >= 1000 {
                    view.removeFromSuperview()
                }
            }
        }
    }
    
    
    open var startPointBlock: (() -> CGPoint)! {
        didSet {
            self.startPoint = startPointBlock()
        }
    }
    open var startButton: PathMenuItem?
    open weak var delegate: PathMenuDelegate?

    open var coverColor: UIColor! = UIColor.clear
    open var itemSize: CGFloat?
    open var itemMargin: CGFloat! = 10
    open var flag: Int?
    open var timer: Timer?
    
    open var timeOffset: CGFloat!

    open var rotateAngle: CGFloat!
    open var menuWholeAngle: CGFloat!
    open var expandRotation: CGFloat!
    open var closeRotation: CGFloat!

    open var animationDuration: CGFloat!
    open var expandRotateAnimationDuration: CGFloat!
    open var closeRotateAnimationDuration: CGFloat!
    open var startMenuAnimationDuration: CGFloat!
    
    open var nearRadius: CGFloat!
    open var endRadius: CGFloat!
    open var farRadius: CGFloat!
    
    open var motionState: State?
    
    open var startPoint: CGPoint = CGPoint.zero {
        didSet {
            startButton?.center = startPoint
            layoutMenu()
        }
    }
    
    //MARK: Image
    
    open var image: UIImage? {
        didSet {
            startButton?.image = image
        }
    }

    open var highlightedImage: UIImage? {
        didSet {
            startButton?.highlightedImage = highlightedImage
        }
    }
    
    open var contentImage: UIImage? {
        didSet {
            startButton?.contentImageView?.image = contentImage
        }
    }
    
    open var highlightedContentImage: UIImage? {
        didSet {
            startButton?.contentImageView?.highlightedImage = highlightedContentImage
        }
    }
    
    //MARK: UIView's methods
    
    override open func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if motionState == .expand { return true }
        return startButton!.frame.contains(point)
    }
    
    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if let animId = anim.value(forKey: "id") {
            if (animId as AnyObject).isEqual("lastAnimation") {
                delegate?.pathMenuDidFinishAnimationClose?(self)
            }
            if (animId as AnyObject).isEqual("firstAnimation") {
                delegate?.pathMenuDidFinishAnimationOpen?(self)
            }
        }
    }
    
    //MARK: UIGestureRecognizer
    
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTap()
    }
    
    //MARK: PathMenuItemDelegate
    
    open func pathMenuItemTouchesBegin(_ item: PathMenuItem) {
        if item == startButton { handleTap() }
    }
    
    open func pathMenuItemTouchesEnd(_ item:PathMenuItem) {
        if item == startButton { return }
        
        let blowup = blowupAnimationAtPoint(item.center)
        item.layer.add(blowup, forKey: "blowup")
        item.center = item.startPoint!

        for (_, menuItem) in menuItems.enumerated() {
            let otherItem = menuItem
            let shrink = shrinkAnimationAtPoint(otherItem.center)
            
            if otherItem.tag == item.tag { continue }
            otherItem.layer.add(shrink, forKey: "shrink")
            otherItem.center = otherItem.startPoint!
        }
        
        motionState = .close
        delegate?.pathMenuWillAnimateClose?(self)
        
        let angle = motionState == .expand ? CGFloat(M_PI_4) + CGFloat(M_PI) : 0.0
        UIView.animate(withDuration: Double(startMenuAnimationDuration!), animations: { [weak self] () -> Void in
            self?.startButton?.transform = CGAffineTransform(rotationAngle: angle)
        })
        self.backgroundColor = UIColor.clear
        delegate?.pathMenu?(self, didSelectIndex: item.tag - 1000)
    }
    
    //MARK: Animation, Position
    
    open func handleTap() {
        let state = motionState!

        let selector: Selector
        let angle: CGFloat
        var destinationColor: UIColor
        
        switch state {
        case .close:
            setMenu()
            delegate?.pathMenuWillAnimateOpen?(self)
            selector = #selector(expand)
            flag = 0
            motionState = .expand
            angle = CGFloat(M_PI_4) + CGFloat(M_PI)
            destinationColor = coverColor
        case .expand:
            setMenu()
            delegate?.pathMenuWillAnimateClose?(self)
            selector = #selector(close)
            flag = menuItems.count - 1
            motionState = .close
            angle = 0
            destinationColor = UIColor.clear
        }
        
        UIView.animate(withDuration: TimeInterval(animationDuration), animations: {
            self.layer.backgroundColor = destinationColor.cgColor
        }, completion: nil)
        
        UIView.animate(withDuration: Double(startMenuAnimationDuration!), animations: { [weak self] () -> Void in
            self?.startButton?.transform = CGAffineTransform(rotationAngle: angle)
        })
        
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: Double(timeOffset!), target: self, selector: selector, userInfo: nil, repeats: true)
            if let timer = timer {
                RunLoop.current.add(timer, forMode: RunLoopMode.commonModes)
            }
        }
    }
    
    open func expand() {
        if flag == menuItems.count {
            timer?.invalidate()
            timer = nil
            return
        }
        
        let tag = 1000 + flag!
        let item = viewWithTag(tag) as! PathMenuItem
        
        let rotateAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.values   = [NSNumber(value: 0.0 as Float), NSNumber(value: Float(expandRotation!) as Float), NSNumber(value: 0.0 as Float)]
        rotateAnimation.duration = CFTimeInterval(expandRotateAnimationDuration!)
        rotateAnimation.keyTimes = [NSNumber(value: 0.0 as Float), NSNumber(value: 0.4 as Float), NSNumber(value: 0.5 as Float)]
        
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.duration = CFTimeInterval(animationDuration!)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: CGFloat(item.startPoint!.x), y: CGFloat(item.startPoint!.y)))
        path.addLine(to: CGPoint(x: item.farPoint!.x, y: item.farPoint!.y))
        path.addLine(to: CGPoint(x: item.nearPoint!.x, y: item.nearPoint!.y))
        path.addLine(to: CGPoint(x: item.endPoint!.x, y: item.endPoint!.y))
        positionAnimation.path = path
        
        let animationgroup: CAAnimationGroup = CAAnimationGroup()
        animationgroup.animations     = [positionAnimation, rotateAnimation]
        animationgroup.duration       = CFTimeInterval(animationDuration!)
        animationgroup.fillMode       = kCAFillModeForwards
        animationgroup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        animationgroup.delegate = self
        
        if flag == menuItems.count - 1 {
            animationgroup.setValue("firstAnimation", forKey: "id")
        }
        
        item.layer.add(animationgroup, forKey: "Expand")
        item.center = item.endPoint!
        
        flag! += 1
    }
    
    open func close() {
        if flag! == -1 {
            timer?.invalidate()
            timer = nil
            return
        }
        
        let tag = 1000 + flag!
        let item = viewWithTag(tag) as! PathMenuItem
        
        let rotateAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.values   = [NSNumber(value: 0.0 as Float), NSNumber(value: Float(closeRotation!) as Float), NSNumber(value: 0.0 as Float)]
        rotateAnimation.duration = CFTimeInterval(closeRotateAnimationDuration!)
        rotateAnimation.keyTimes = [NSNumber(value: 0.0 as Float), NSNumber(value: 0.4 as Float), NSNumber(value: 0.5 as Float)]
        
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.duration = CFTimeInterval(animationDuration!)
        let path: CGMutablePath = CGMutablePath()
        path.move(to: CGPoint(x: item.endPoint!.x, y: item.endPoint!.y))
        path.addLine(to: CGPoint(x: item.farPoint!.x, y: item.farPoint!.y))
        path.addLine(to: CGPoint(x: CGFloat(item.startPoint!.x), y: CGFloat(item.startPoint!.y)))
        positionAnimation.path = path
        
        let animationgroup = CAAnimationGroup()
        animationgroup.animations     = [positionAnimation, rotateAnimation]
        animationgroup.duration       = CFTimeInterval(animationDuration!)
        animationgroup.fillMode       = kCAFillModeForwards
        animationgroup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        animationgroup.delegate = self

        if flag == 0 {
            animationgroup.setValue("lastAnimation", forKey: "id")
        }
        
        item.layer.add(animationgroup, forKey: "Close")
        item.center = item.startPoint!
        
        flag! -= 1
    }
    
    open func setMenu() {
        let count = menuItems.count
        for (index, menuItem) in menuItems.enumerated() {
            let item = menuItem
            item.tag = 1000 + index
            if menuWholeAngle >= CGFloat(M_PI) * 2 {
                menuWholeAngle = menuWholeAngle! - menuWholeAngle! / CGFloat(count)
            }
            item.delegate = self
            insertSubview(item, belowSubview: startButton!)
        }
        layoutMenu()
    }
    
    func layoutMenu() {
        let count = menuItems.count
        for (index, menuItem) in menuItems.enumerated() {
            let item = menuItem

            item.startPoint = startPoint

            let endPointY = startPoint.y - (itemSize! + itemMargin) * CGFloat(index + 1)
            item.endPoint = CGPoint(x: startPoint.x, y: endPointY)

            let nearPointY = startPoint.y - (itemSize! + itemMargin) * CGFloat(index + 1) + Distance.DownDiff
            item.nearPoint = CGPoint(x: startPoint.x, y: nearPointY)

            let farPointY = startPoint.y - (itemSize! + itemMargin) * CGFloat(index + 1) - Distance.UpDiff
            item.farPoint = CGPoint(x: startPoint.x, y: farPointY)
            
            let state = motionState!
            switch state {
                case .close:
                   item.center = item.startPoint!
                case .expand:
                   item.center = item.endPoint!
            }
        }

    }
    
    fileprivate func RotateCGPointAroundCenter(_ point: CGPoint, center: CGPoint, angle: CGFloat) -> CGPoint {
        let translation = CGAffineTransform(translationX: center.x, y: center.y)
        let rotation = CGAffineTransform(rotationAngle: angle)
        let transformGroup = translation.inverted().concatenating(rotation).concatenating(translation)
        return point.applying(transformGroup)
    }
    
    fileprivate func blowupAnimationAtPoint(_ p: CGPoint) -> CAAnimationGroup {
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = [NSValue(cgPoint: p)]
        positionAnimation.keyTimes = [3]
 
        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.toValue = NSValue(caTransform3D: CATransform3DMakeScale(3, 3, 1))
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.toValue = NSNumber(value: 0.0 as Float)
        
        let animationgroup = CAAnimationGroup()
        animationgroup.animations = [positionAnimation, scaleAnimation, opacityAnimation]
        animationgroup.duration = CFTimeInterval(animationDuration!)
        animationgroup.fillMode = kCAFillModeForwards
        
        return animationgroup
    }
    
    fileprivate func shrinkAnimationAtPoint(_ p: CGPoint) -> CAAnimationGroup {
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.values = [NSValue(cgPoint: p)]
        positionAnimation.keyTimes = [3]
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform")
        scaleAnimation.toValue = NSValue(caTransform3D: CATransform3DMakeScale(0.01, 0.01, 1))

        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.toValue = NSNumber(value: 0.0 as Float)
        
        let animationgroup = CAAnimationGroup()
        animationgroup.animations = [positionAnimation, scaleAnimation, opacityAnimation]
        animationgroup.duration = CFTimeInterval(animationDuration!)
        animationgroup.fillMode = kCAFillModeForwards
        
        return animationgroup
    }
}
