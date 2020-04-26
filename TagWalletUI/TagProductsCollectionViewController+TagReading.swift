//
//  TagProductsCollectionViewController+TagReading.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import UIKit
import CoreNFC

extension TagProductsCollectionViewContoller {
    @IBAction func startTagReadingSession() {
        tagReaderSession = NFCTagReaderSession(pollingOption: NFCTagReaderSession.PollingOption.iso14443, delegate: self)
        tagReaderSession?.alertMessage = "Hold tag to back of phone!"
        tagReaderSession?.begin()
    }
    func handleConnectedTag(tag: NFCMiFareTag) {
        NTAG215Tag.initialize(tag: tag) { result in
            switch result {
            case .success(let ntag215Tag):
                if let tagProduct = self.tagWallet?.tagProducts.first(where: { $0.head + $0.tail == ntag215Tag.dump.headHex + ntag215Tag.dump.tailHex }) {
                    self.tagReaderSession?.invalidate()
                    DispatchQueue.main.async {
                        self.showTagProduct(tagProduct, newDump: ntag215Tag.dump)
                    }
                } else {
                    self.unknownProductTag(ntag215Tag: ntag215Tag)
                }
            case .failure(let error):
                self.tagReaderSession?.invalidate(errorMessage: error.localizedDescription)
            }
        }
    }
    func unknownProductTag(ntag215Tag: NTAG215Tag) {
        let alert = UIAlertController(title: "Unknown NTAG215 Product", message: "What do you want to name it?", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Product Name.."
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { action in
            let tagProduct = TagProduct.init(productSeries: "", character: "", gameSeries: "", imageURL: "", name: alert.textFields?.first?.text ?? "", type: "", head: ntag215Tag.dump.headHex, tail: ntag215Tag.dump.tailHex, dumps: [ntag215Tag.dump])
            self.tagWallet?.tagProducts += [tagProduct]
            self.saveTagWallet()            
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
extension TagProductsCollectionViewContoller : NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        NSLog("tagReaderSessionDidBecomeActive")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        NSLog("NFCTagReaderSession, didInvalidateWithError \(error)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard case let NFCTag.miFare(tag) = tags.first! else {
            tagReaderSession?.invalidate(errorMessage: "Invalid tag type.")
            return
        }                
        session.connect(to: tags.first!) { (error: Error?) in
            if let error = error {
                session.invalidate(errorMessage: error.localizedDescription)
            } else {
                self.handleConnectedTag(tag: tag)
            }
        }
    }
}
