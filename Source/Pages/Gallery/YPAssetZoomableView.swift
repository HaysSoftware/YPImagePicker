//
//  YPAssetZoomableView.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 2015/11/16.
//  Edited by Nik Kov || nik-kov.com on 2018/04
//  Copyright © 2015 Yummypets. All rights reserved.
//

import UIKit
import Photos

protocol YPAssetZoomableViewDelegate: class {
    func ypAssetZoomableViewDidLayoutSubviews(_ zoomableView: YPAssetZoomableView)
    func ypAssetZoomableViewScrollViewDidZoom()
    func ypAssetZoomableViewScrollViewDidEndZooming()
}

final class YPAssetZoomableView: UIScrollView {
    public weak var myDelegate: YPAssetZoomableViewDelegate?
    public var cropAreaDidChange = {}
    public var isVideoMode = false
    public var photoImageView = UIImageView()
    public var videoView = YPVideoView()
    public var aspectZoomScale: CGFloat = 1
    public var minWidth: CGFloat? = YPConfig.library.minWidthForItem
    
    fileprivate var currentAsset: PHAsset?
    
    // Image view of the asset for convenience. Can be video preview image view or photo image view.
    public var assetImageView: UIImageView {
        return isVideoMode ? videoView.previewImageView : photoImageView
    }

    /// Set zoom scale to fit the image to square or show the full image
    //
    /// - Parameters:
    ///   - fit: If true - zoom to show squared. If false - show full.
    public func fitImage(_ fit: Bool, animated isAnimated: Bool = false) {
        aspectZoomScale = calculateZoomScale()
        if fit {
            setZoomScale(aspectZoomScale, animated: isAnimated)
        } else {
            setZoomScale(1, animated: isAnimated)
        }
    }
    
    /// Re-apply correct scrollview settings if image has already been adjusted in
    /// multiple selection mode so that user can see where they left off.
    public func applyStoredCropPosition(_ scp: YPLibrarySelection) {
        // ZoomScale needs to be set first.
        if let zoomScale = scp.scrollViewZoomScale {
            setZoomScale(zoomScale, animated: false)
        }
        if let contentOffset = scp.scrollViewContentOffset {
            setContentOffset(contentOffset, animated: false)
        }
    }
    
    public func setVideo(_ video: PHAsset,
                         mediaManager: LibraryMediaManager,
                         storedCropPosition: YPLibrarySelection?,
                         completion: @escaping () -> Void) {
        mediaManager.imageManager?.fetchPreviewFor(video: video) { [weak self] preview in
            guard let strongSelf = self else { return }
            guard strongSelf.currentAsset != video else { completion() ; return }
            
            if strongSelf.videoView.isDescendant(of: strongSelf) == false {
                strongSelf.isVideoMode = true
                strongSelf.photoImageView.removeFromSuperview()
                strongSelf.addSubview(strongSelf.videoView)
            }
            
            strongSelf.videoView.setPreviewImage(preview)
            
            strongSelf.setAssetFrame(for: strongSelf.videoView, with: preview)
            
            completion()
            
            // Stored crop position in multiple selection
            if let scp173 = storedCropPosition {
                strongSelf.applyStoredCropPosition(scp173)
            }
        }
        mediaManager.imageManager?.fetchPlayerItem(for: video) { [weak self] playerItem in
            guard let strongSelf = self else { return }
            guard strongSelf.currentAsset != video else { completion() ; return }
            strongSelf.currentAsset = video

            strongSelf.videoView.loadVideo(playerItem)
            strongSelf.videoView.play()
        }
    }
    
    public func setImage(_ photo: PHAsset,
                         mediaManager: LibraryMediaManager,
                         storedCropPosition: YPLibrarySelection?,
                         completion: @escaping () -> Void) {
        guard currentAsset != photo else { DispatchQueue.main.async { completion() }; return }
        currentAsset = photo
        
        mediaManager.imageManager?.fetch(photo: photo) { [weak self] image, _ in
            guard let strongSelf = self else { return }
            
            if strongSelf.photoImageView.isDescendant(of: strongSelf) == false {
                strongSelf.isVideoMode = false
                strongSelf.videoView.removeFromSuperview()
                strongSelf.videoView.showPlayImage(show: false)
                strongSelf.videoView.deallocate()
                strongSelf.addSubview(strongSelf.photoImageView)
            
                strongSelf.photoImageView.contentMode = .scaleAspectFill
                strongSelf.photoImageView.clipsToBounds = true
            }
            
            strongSelf.photoImageView.image = image
           
            strongSelf.setAssetFrame(for: strongSelf.photoImageView, with: image)
        
            completion()
            
            // Stored crop position in multiple selection
            if let scp173 = storedCropPosition {
                strongSelf.applyStoredCropPosition(scp173)
            }
        }
    }
    
    fileprivate func setAssetFrame(`for` view: UIView, with image: UIImage) {
        // Reseting the previous scale
        self.minimumZoomScale = 1
        self.zoomScale = 1
        
        // Calculating and setting the image view frame depending on screenWidth
        let viewSize: CGSize = self.bounds.size
        let w = image.size.width
        let h = image.size.height

        var zoomScale: CGFloat = 1

        switch image.size.orientation {
        case .landscape:
            view.frame.size.width = viewSize.width
            view.frame.size.height = viewSize.width / image.size.aspectRatio()
        case .portrait: fallthrough
        case .square:
            view.frame.size.width = viewSize.height * image.size.aspectRatio()
            view.frame.size.height = viewSize.height
            
            if let minWidth = minWidth {
                let k = minWidth / viewSize.width
                zoomScale = (h / w) * k
            }
        }
        
        // Centering image view
        view.center = center
        centerAssetView()
        
        // Setting new scale
        minimumZoomScale = zoomScale
        self.zoomScale = zoomScale
    }
    
    /// Calculate zoom scale which will fit the image to the view
    fileprivate func calculateZoomScale() -> CGFloat {
        guard let image = assetImageView.image else {
            print("YPAssetZoomableView >>> No image"); return 1.0
        }
        
        switch image.size.orientation {
        case .landscape:
            return image.size.aspectRatio() / bounds.size.aspectRatio()
        case .portrait: fallthrough
        case .square:
            return image.size.flipped().aspectRatio() * bounds.size.aspectRatio()
        }
    }
    
    // Centring the image frame
    fileprivate func centerAssetView() {
        let assetView = isVideoMode ? videoView : photoImageView
        let scrollViewBoundsSize = self.bounds.size
        var assetFrame = assetView.frame
        let assetSize = assetView.frame.size
        
        assetFrame.origin.x = (assetSize.width < scrollViewBoundsSize.width) ?
            (scrollViewBoundsSize.width - assetSize.width) / 2.0 : 0
        assetFrame.origin.y = (assetSize.height < scrollViewBoundsSize.height) ?
            (scrollViewBoundsSize.height - assetSize.height) / 2.0 : 0.0
        
        assetView.frame = assetFrame
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        frame.size      = CGSize.zero
        clipsToBounds   = true
        photoImageView.frame = CGRect(origin: CGPoint.zero, size: CGSize.zero)
        videoView.frame = CGRect(origin: CGPoint.zero, size: CGSize.zero)
        maximumZoomScale = 6.0
        minimumZoomScale = 1
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator   = false
        delegate = self
        alwaysBounceHorizontal = true
        alwaysBounceVertical = true
        isScrollEnabled = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        myDelegate?.ypAssetZoomableViewDidLayoutSubviews(self)
    }
}

// MARK: UIScrollViewDelegate Protocol
extension YPAssetZoomableView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return isVideoMode ? videoView : photoImageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        myDelegate?.ypAssetZoomableViewScrollViewDidZoom()
        
        centerAssetView()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        guard let view = view, view == photoImageView || view == videoView else { return }
        
        // prevent to zoom out
        if YPConfig.library.onlySquare && scale < aspectZoomScale {
            self.fitImage(true, animated: true)
        }
        
        myDelegate?.ypAssetZoomableViewScrollViewDidEndZooming()
        cropAreaDidChange()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        cropAreaDidChange()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        cropAreaDidChange()
    }
}

public typealias AspectRatio = CGSize
public extension AspectRatio {
    enum Orientation {
        case landscape
        case portrait
        case square
    }
    func aspectRatio(precision: Int? = nil) -> CGFloat {
        let aspectRatio = width / height
        
        guard let precision = precision else {
            return aspectRatio
        }
        
        let multiplier = pow(10, Double(precision))
        
        let value = (Double(aspectRatio) * multiplier).rounded() / multiplier
        return CGFloat(value)
    }
    
    var orientation: Orientation {
        switch self.aspectRatio() {
        case let aspect where aspect > 1.0:
            return .landscape
        case let aspect where aspect < 1.0:
            return .portrait
        default:
            return .square
        }
    }
    
    func flipped() -> AspectRatio {
        return AspectRatio(width: height, height: width)
    }
    
    func width(for height: CGFloat) -> CGFloat {
        return height * aspectRatio()
    }
    
    func height(for width: CGFloat) -> CGFloat {
        return width / aspectRatio()
    }
    
    static let square = AspectRatio(width: 1.0, height: 1.0)
    static let standard = AspectRatio(width: 4.0, height: 3.0)
    static let wideScreen = AspectRatio(width: 16.0, height: 9.0)
    static let theater = AspectRatio(width: 21.0, height: 9.0)
    static let imax = AspectRatio(width: 1.9, height: 1.0)
}
