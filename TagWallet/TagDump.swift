//
//  TagDump.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation

typealias TagUID = Data // Full Nine-byte UID
typealias TagSignature = Data // 32-byte signature

struct TagDump : Codable, Equatable {
    enum Error : Swift.Error {
        case invalidUID
    }
    let data: Data
    let isLocked: Bool
    let isAmiibo: Bool
    
    init?(data: Data) {
        guard data.count == 532 || data.count == 540 || data.count == 572 else {
            NSLog("TagDump: invalid data of \(data.count)")
            return nil }
        self.data = data
        self.isLocked = data[10] != 0 && data[11] != 0
        self.isAmiibo = data[10...15].elementsEqual([0x0F, 0xE0, 0xF1, 0x10, 0xFF, 0xEE]) && data[520...522].elementsEqual([0x01, 0x00, 0x0F]) && data[524...531].elementsEqual([0x00, 0x00, 0x00, 0x04, 0x5F, 0x00, 0x00, 0x00])
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
    var fullHex: String {
        return data[84..<92].map { String(format: "%02hhx", $0) }.joined()
    }
    
    
    var uid: TagUID { data.subdata(in: 0..<9) }
    var signature: TagSignature? {
        if data.count == 572 {
            return data[540..<572]
        }
        return nil
    }
    var gameSeriesHex: String {
        return String(fullHex.prefix(3))
    }
    var amiiboSeriesHex: String {
        return String(fullHex.prefix(14).suffix(2))
    }
    var typeHex: String {
        return String(fullHex.prefix(8).suffix(2))
    }
    
    private var writeCounter: Data { data.subdata(in: 17..<19) }
    var writeCounterInt: UInt16 {
        if data[16] != 0xA5 {
            return 0
        }
        
        let counterHex = writeCounter
        return (UInt16(counterHex[0]) << 8) | UInt16(counterHex[1])
    }
    var keygenSalt: Data { data.subdata(in: 96..<128) }
    
    func patchedDump(withUID newUID: TagUID, staticKey: TagKey, dataKey: TagKey, skipDecrypt: Bool = false, withSalt newSalt: Data? = nil) throws -> TagDump {
        guard newUID.count == 9 else {
            throw Error.invalidUID
        }
        
        // Decrypt the data
        let decryptedData = try { () -> Data in
            if skipDecrypt {
                return Data(data.subdata(in: 20..<52) + data.subdata(in: 160..<520))
            }
            
            let decryptDataKeys = dataKey.derivedKey(uid: uid, writeCounter: writeCounter, salt: keygenSalt)
            return try decryptDataKeys.decrypt(data.subdata(in: 20..<52) + data.subdata(in: 160..<520))
        }()
        
        var paddedDecrypted = Data(count: 392)
        paddedDecrypted[0..<(decryptedData.count)] = decryptedData[0..<(decryptedData.count)]
        
        if paddedDecrypted.count != decryptedData.count {
            print("Decrypted data size mismatch")
        }
        
        let newSalt = newSalt ?? keygenSalt
        
        

        var newData = Data(data)
        newData[0..<9] = newUID
        newData[20..<52] = paddedDecrypted[0..<32]
        newData[160..<520] = paddedDecrypted[32..<392]
        newData[96..<128] = newSalt[0..<32]
        
                
        // Generated tag HMAC
        let encryptTagKeys = staticKey.derivedKey(uid: newUID, writeCounter: writeCounter, salt: newSalt)
        let tagHMAC = encryptTagKeys.hmac(newData.subdata(in: 0..<8) + newData.subdata(in: 84..<128))
        newData[52..<84] = tagHMAC
        
        // Generated data HMAC
        let encryptDataKeys = dataKey.derivedKey(uid: newUID, writeCounter: writeCounter, salt: newSalt)
        let dataHMAC = encryptDataKeys.hmac(newData.subdata(in: 17..<52) + newData.subdata(in: 160..<520) + newData.subdata(in: 52..<84) + newData.subdata(in: 0..<8) + newData.subdata(in: 84..<128))
        newData[128..<160] = dataHMAC
        
        // Re-encrypt the data
        let encryptedData = try encryptDataKeys.decrypt(decryptedData)
        
        var paddedEncrypted = Data(count: 392)
        paddedEncrypted[0..<(encryptedData.count)] = encryptedData[0..<(encryptedData.count)]
        
        if paddedEncrypted.count != encryptedData.count {
            print("Encrypted data size mismatch")
        }
        
        newData[20..<52] = paddedEncrypted[0..<32]
        newData[160..<520] = paddedEncrypted[32..<392]
            
        return TagDump(data: newData)!
    }
}


