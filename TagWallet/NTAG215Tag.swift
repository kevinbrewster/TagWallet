//
//  NTAG215Tag.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/21/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import CoreNFC

class NTAG215Tag {
    enum Error : Swift.Error {
        case invalidTagType
        case unknownError
    }
    
    
    let tag: NFCMiFareTag
    let versionInfo: NFCMiFareTagVersionInfo
    let dump: TagDump
    var isLocked: Bool
    var isAmiibo: Bool
    
    static func initialize(tag: NFCMiFareTag, completionHandler: @escaping (Result<NTAG215Tag, Swift.Error>) -> Void) {
        tag.getVersion() { result in
            switch result {
            case .failure(let error):
                completionHandler(.failure(error))
            case .success(let versionInfo):
                guard versionInfo.isNFC215 else {
                    completionHandler(.failure(Error.invalidTagType))
                    return
                }
                tag.getSignature { result in
                    switch result {
                    case .failure(let error):
                        completionHandler(.failure(error))
                    case .success(let signature):
                        guard signature.count == 32 else {
                            completionHandler(.failure(Error.invalidTagType))
                            return
                        }

                        tag.fastRead(start: 0, end: 0x86, batchSize: 0x20) { (data, error) in
                            if let ntag215Tag = NTAG215Tag(tag: tag, versionInfo: versionInfo, data: data, signature: signature) {
                                completionHandler(.success(ntag215Tag))
                            } else {
                                completionHandler(.failure(Error.unknownError))
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    init?(tag: NFCMiFareTag, versionInfo: NFCMiFareTagVersionInfo, data: Data, signature: Data) {
        guard versionInfo.isNFC215 else {
            return nil
        }
        guard let dump = TagDump(data: data + signature) else {
            return nil
        }
        self.tag = tag
        self.versionInfo = versionInfo
        self.dump = dump
        isLocked = dump.isLocked
        isAmiibo = dump.isAmiibo
    }
    
    func patchAndWriteDump(_ originalDump: TagDump, staticKey: TagKey, dataKey: TagKey, completionHandler: @escaping (NFCMiFareTagWriteResult) -> Void) {
        do {
            let patchedDump = try originalDump.patchedDump(withUID: dump.uid, staticKey: staticKey, dataKey: dataKey)

            var writes = [(Int, Data)]()

            // Main Data
            for page in 3..<130 {
                let dataStartIndex = page * 4
                writes += [(page, patchedDump.data.subdata(in: dataStartIndex..<dataStartIndex+4))]
            }

            writes += [(134, Data([0x80, 0x80, 0, 0]))] // PACK / RFUI
            writes += [(133, try TagDump.password(uid: dump.uid))] // Password
            writes += [(2, Data([patchedDump.data[8], patchedDump.data[9], 0x0F, 0xE0]))] // Lock Bits
            writes += [(130, Data([0x01, 0x00, 0x0F, 0x00]))] // Dynamic Lock Bits
            writes += [(131, Data([0x00, 0x00, 0x00, 0x04]))] // Config
            writes += [(132, Data([0x5F, 0x00, 0x00, 0x00]))] // Config

            tag.write(batch: writes) { result in
                completionHandler(result)
            }
        } catch let error {
            completionHandler(.failure(error))
        }
    }
    
    func writeAppData(_ dump: TagDump, completionHandler: @escaping (NFCMiFareTagWriteResult) -> Void) {
        do {
            let password = try TagDump.password(uid: dump.uid)
            var writes = [(Int, Data)]()
            
            tag.sendMiFareCommand(commandPacket: Data([0x1B] + password[0..<4])) { (data, error) in
                if error != nil {
                    completionHandler(.failure(error!))
                    return
                }
                
                if data.elementsEqual([0x80, 0x80]) {
                    for page in 4...12 {
                        let dataStartIndex = page * 4
                        writes += [(page, dump.data.subdata(in: dataStartIndex..<dataStartIndex+4))]
                    }
                    
                    for page in 32...129 {
                        let dataStartIndex = page * 4
                        writes += [(page, dump.data.subdata(in: dataStartIndex..<dataStartIndex+4))]
                    }

                    self.tag.write(batch: writes) { result in
                        completionHandler(result)
                    }
                } else {
                    completionHandler(.success)
                }
            }
        } catch let error {
            completionHandler(.failure(error))
        }
    }
    
    func patchAndWriteAppData(_ originalDump: TagDump, staticKey: TagKey, dataKey: TagKey, completionHandler: @escaping (NFCMiFareTagWriteResult) -> Void) {
        do {
            let patchedDump = try originalDump.patchedDump(withUID: dump.uid, staticKey: staticKey, dataKey: dataKey)
            
            writeAppData(patchedDump, completionHandler: completionHandler)
        } catch let error {
            completionHandler(.failure(error))
        }
    }
}

extension NFCMiFareTagVersionInfo {
    var isNFC215: Bool {
        return productType == 0x04 && storageSize == 0x11
    }
}
