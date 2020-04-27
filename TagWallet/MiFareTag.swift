//
//  MiFareTag.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/20/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import CoreNFC
import CryptoSwift

enum NFCMiFareTagError : Swift.Error {
    case invalidData
    case invalidArgument
    case crcError
    case invalidAuthentication
    case eepromWriteError
    case unknownError
}
enum NFCMiFareTagWriteResult {
    case success
    case failure(Error)
    
    init(ack: UInt8) {
        switch ack {
        case 0x0A:
            self = .success
        case 0x00:
            self = .failure(NFCMiFareTagError.invalidArgument)
        case 0x01:
            self = .failure(NFCMiFareTagError.crcError)
        case 0x04:
            self = .failure(NFCMiFareTagError.invalidAuthentication)
        case 0x05:
            self = .failure(NFCMiFareTagError.eepromWriteError)
        default:
            self = .failure(NFCMiFareTagError.unknownError)
        }
    }
}
struct NFCMiFareTagVersionInfo {
    private let data: Data
    var header: UInt8 { return data[0] }
    var vendorID: UInt8 { return data[1] }
    var productType: UInt8 { return data[2] }
    var productSubtype: UInt8 { return data[3] }
    var majorProductVersion: UInt8 { return data[4] }
    var minorProductVersion: UInt8 { return data[5] }
    var storageSize: UInt8 { return data[6] }
    var protocolType: UInt8 { return data[7] }
    
    init?(data: Data) {
        guard data.count == 8 else { return nil }
        self.data = data
    }
}
extension NFCMiFareTag {
    func getVersion(completionHandler: @escaping (Result<NFCMiFareTagVersionInfo, Error>) -> Void) {
        sendMiFareCommand(commandPacket: Data([0x60])) { (data, error) in
            if let error = error {
                completionHandler(.failure(error))
            } else if let versionInfo = NFCMiFareTagVersionInfo(data: data) {
                completionHandler(.success(versionInfo))
            } else {
                completionHandler(.failure(NFCMiFareTagError.unknownError))
            }
        }
    }
    func fastRead(start: UInt8, end: UInt8, batchSize: UInt8, completionHandler: @escaping (Data, Error?) -> Void) {
        // FAST_READ seems to timeout if you try to read too many pages at once, so necessary to read in batches!
        _fastRead(start: start, end: end, batchSize: batchSize, accumulatedData: Data(), completionHandler: completionHandler)
    }
    private func _fastRead(start: UInt8, end: UInt8, batchSize: UInt8, accumulatedData: Data, completionHandler: @escaping (Data, Error?) -> Void) {
        // Note: The FAST_READ Command is INCLUSIVE of both the start page end page!
        let batchEnd = min(start + batchSize - 1, end)
        sendMiFareCommand(commandPacket: Data([0x3A, start, batchEnd])) { (data, error) in
            guard error == nil else {
                completionHandler(Data(), error)
                return
            }
            let accumulatedData = accumulatedData + data
            
            if batchEnd < end {
                self._fastRead(start: batchEnd + 1, end: end, batchSize: batchSize, accumulatedData: accumulatedData, completionHandler: completionHandler)
            } else {
                completionHandler(accumulatedData, nil)
            }
        }
    }
    func write(page: Int, data: Data, completionHandler: @escaping (NFCMiFareTagWriteResult) -> Void) {
        guard page < 255, data.count == 4 else {
            completionHandler(NFCMiFareTagWriteResult.failure(NFCMiFareTagError.invalidData))
            return
        }
        let commandPacket = Data([0xA2, UInt8(page)]) + data
        sendMiFareCommand(commandPacket: commandPacket) { (data, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            guard data.count == 1 else {
                completionHandler(.failure(NFCMiFareTagError.unknownError))
                return
            }
            completionHandler(NFCMiFareTagWriteResult(ack: data[0]))
        }
    }
    func write(batch: [(page: Int, data: Data)], completionHandler: @escaping (NFCMiFareTagWriteResult) -> Void) {
        if let write = batch.first {
            //NSLog("Gonna write page #\(batch.page)")
            self.write(page: write.page, data: write.data) { result in
                switch result {
                    case .success:
                        self.write(batch: Array(batch[1..<batch.count]), completionHandler: completionHandler)
                    case .failure(let error):
                        // End early if there's an error
                        completionHandler(.failure(error))
                }
            }
        } else {
            // all done
            completionHandler(.success)
        }
    }
}


extension Data {
    func mifareDescription() -> String {
        /*guard count == 540 else {
            return "[[INVALID]]]"
        }*/
        let pages = count / 4
        var string = ""
        for page in 0..<pages {
            string += "Page #\(page):\t"
            for i in 0..<4 {
                if (4 * page) + i >= count { break }
                string += "\(String(self[(4 * page) + i]))\t"
            }
            string += "\n"
        }
        return string
    }
}
