//
//  TagDump.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation

typealias TagUID = Data // Full Nine-byte UID

struct TagDump : Codable, Equatable {
    enum Error : Swift.Error {
        case invalidUID
    }
    let data: Data
    
    init?(data: Data) {
        guard data.count >= 532 else {
            NSLog("TagDump: invalid data of \(data.count)")
            return nil }
        self.data = data.subdata(in: 0..<min(532, data.count))
    }
    
    static func password(uid: TagUID) throws -> Data {
        guard uid.count == 9 else {
            throw Error.invalidUID
        }
        var password = Data(repeating: 0, count: 4)
        password[0] = 0xAA ^ (uid[1] ^ uid[4])
        password[1] = 0x55 ^ (uid[2] ^ uid[5])
        password[2] = 0xAA ^ (uid[4] ^ uid[6])
        password[3] = 0x55 ^ (uid[5] ^ uid[7])
        return password
    }
    var headHex: String {
        return data[84..<88].map { String(format: "%02hhx", $0) }.joined()
    }
    var tailHex: String {
        return data[88..<92].map { String(format: "%02hhx", $0) }.joined()
    }
    
    
    var uid: TagUID { data.subdata(in: 0..<9) }
    private var writeCounter: Data { data.subdata(in: 17..<19) }
    private var keygenSalt: Data { data.subdata(in: 96..<128) }
    
    func patchedDump(withUID newUID: TagUID, staticKey: TagKey, dataKey: TagKey) throws -> TagDump {
        guard newUID.count == 9 else {
            throw Error.invalidUID
        }
        // Decrypt the data
        let decryptDataKeys = dataKey.derivedKey(uid: uid, writeCounter: writeCounter, salt: keygenSalt)
        let decryptedData = try decryptDataKeys.decrypt(data.subdata(in: 20..<52) + data.subdata(in: 160..<520))
        
        var newData = Data(data)
        newData[0..<9] = newUID
        newData[20..<52] = decryptedData[0..<32]
        newData[160..<520] = decryptedData[32..<392]
        
                
        // Generated tag HMAC
        let encryptTagKeys = staticKey.derivedKey(uid: newUID, writeCounter: writeCounter, salt: keygenSalt)
        let tagHMAC = encryptTagKeys.hmac(newData.subdata(in: 0..<8) + newData.subdata(in: 84..<128))
        newData[52..<84] = tagHMAC
        
        // Generated data HMAC
        let encryptDataKeys = dataKey.derivedKey(uid: newUID, writeCounter: writeCounter, salt: keygenSalt)
        let dataHMAC = encryptDataKeys.hmac(newData.subdata(in: 17..<52) + newData.subdata(in: 160..<520) + newData.subdata(in: 52..<84) + newData.subdata(in: 0..<8) + newData.subdata(in: 84..<128))
        newData[128..<160] = dataHMAC
        
        // Re-encrypt the data
        let encryptedData = try encryptDataKeys.decrypt(decryptedData)
        newData[20..<52] = encryptedData[0..<32]
        newData[160..<520] = encryptedData[32..<392]
            
        return TagDump(data: newData)!
    }
}


