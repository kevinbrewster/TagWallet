//
//  TagProduct.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import UIKit

struct TagProduct: Codable {
    let productSeries: String
    let character: String
    let gameSeries: String
    let imageURL: String
    let name: String
    let type: String
    let head: String
    let tail: String
    let dumps: [TagDump]
    
    static let imageDataCache = NSCache<NSString, NSData>()
    
    func getImage(completion: @escaping (UIImage?) -> Void) {
        if let imageData = Self.imageDataCache.object(forKey: imageURL as NSString) {
            completion(UIImage(data: imageData as Data))
        } else if let url = URL(string: imageURL) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                guard let imageData = data else { return }
                DispatchQueue.main.async {
                    Self.imageDataCache.setObject(imageData as NSData, forKey: self.imageURL as NSString)
                    completion(UIImage(data: imageData))
                }
            }.resume()
        }
    }
}

struct TagWallet: Codable {
    var tagProducts: [TagProduct]
    let staticKey: TagKey?
    let dataKey: TagKey?
}
