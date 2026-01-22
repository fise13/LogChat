//
//  ImageProcessor.swift
//  LogChat
//
//  Created by Виктор on 04.01.2026.
//

import Foundation
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#endif

class ImageProcessor {
    static let shared = ImageProcessor()
    
    private init() {}
    
    #if os(iOS)
    func compressImage(_ image: UIImage, quality: CGFloat = 0.8, maxDimension: CGFloat = 1024) -> Data? {
        // Вычисляем новый размер
        let size = image.size
        var newSize = size
        
        if max(size.width, size.height) > maxDimension {
            let ratio = maxDimension / max(size.width, size.height)
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        }
        
        // Создаем новый контекст
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        
        // Конвертируем в JPEG
        return resizedImage.jpegData(compressionQuality: quality)
    }
    
    func compressImageData(_ imageData: Data, quality: CGFloat = 0.8, maxDimension: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: imageData) else {
            return nil
        }
        return compressImage(image, quality: quality, maxDimension: maxDimension)
    }
    #endif
}
