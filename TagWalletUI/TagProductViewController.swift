//
//  TagProductViewController.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import UIKit
import CryptoKit
import CoreNFC

class TagProductViewController : UITableViewController {
    @IBOutlet weak var imageView: UIImageView!
    
    var tagProduct: TagProduct!
    var staticKey: TagKey?
    var dataKey: TagKey?
    
    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()
    
    internal var tagReaderSession: NFCTagReaderSession?
    var dumpToWrite: TagDump?
    var newlyReadDump: TagDump?
    weak var tagProductsCollectionViewContoller: TagProductsCollectionViewContoller?
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        title = tagProduct.name
        navigationItem.prompt = tagProduct.productSeries
        tagProduct.getImage { self.imageView.image = $0 }
        
        if tagProduct.dumps.count > 0 {
            tableView.tableFooterView = nil
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let newlyReadDump = newlyReadDump, !tagProduct.dumps.contains(newlyReadDump) {
            let alert = UIAlertController(title: "Do you want to save this dump?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                // todo: Add dump to wallet
            }))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}
extension TagProductViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tagProduct.dumps.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Dump", for: indexPath)
        let dump = tagProduct.dumps[indexPath.row]
        cell.textLabel?.text = "Tag Dump"
        cell.detailTextLabel?.text = "\(SHA256.hash(data: dump.data))"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dumpToWrite = nil
        
        if staticKey != nil && dataKey != nil {
            // We have the decryption keys so we can proceed with writing dump to tag
            let alert = UIAlertController(title: "Write to blank NTAG215?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Write", style: .default, handler: { action in
                self.dumpToWrite = self.tagProduct.dumps[indexPath.row]
                self.tagReaderSession = NFCTagReaderSession(pollingOption: NFCTagReaderSession.PollingOption.iso14443, delegate: self)
                self.tagReaderSession?.alertMessage = "Hold blank NFC215 tag to phone."
                self.tagReaderSession?.begin()
                self.tableView.deselectRow(at: indexPath, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                self.tableView.deselectRow(at: indexPath, animated: true)
            }))
            present(alert, animated: true, completion: nil)
            
        } else {
            let alert = UIAlertController(title: "No decryption keys in wallet!", message: "You cannot write this dump without decryption keys!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}
extension TagProductViewController {
    func writeDump(to ntag215Tag: NTAG215Tag) {
        guard let dumpToWrite = dumpToWrite, let staticKey = staticKey, let dataKey = dataKey else {
            return
        }
        ntag215Tag.patchAndWriteDump(dumpToWrite, staticKey: staticKey, dataKey: dataKey) {result in
            switch result {
            case .success:
                self.tagReaderSession?.invalidate()
                self.dumpToWrite = nil
                
                let alert = UIAlertController(title: "Tag successfully written!", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alert, animated: true, completion: nil)
                }
                
            case .failure(let error):
                self.tagReaderSession?.invalidate(errorMessage: error.localizedDescription)
            }
        }
    }
    func handleConnectedTag(tag: NFCMiFareTag) {
        NTAG215Tag.initialize(tag: tag) { result in
            switch result {
            case .success(let ntag215Tag):
                if ntag215Tag.isLocked {
                    self.tagReaderSession?.invalidate(errorMessage: "Tag is locked! Can't overwrite!")
                } else {
                    self.writeDump(to: ntag215Tag)
                }
            case .failure(let error):
                self.tagReaderSession?.invalidate(errorMessage: error.localizedDescription)
            }
        }
    }
}
extension TagProductViewController : NFCTagReaderSessionDelegate {
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

