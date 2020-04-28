//
//  TagEncyption.swift
//  TagWallet
//
//  Created by Kevin Brewster on 4/23/20.
//  Copyright © 2020 Kevin Brewster. All rights reserved.
//

import Foundation
import CryptoKit
import CryptoSwift

struct TagKey : Codable {
    private let data: Data // 80 bytes
    
    var hmacKey: Data { data.subdata(in: 0..<16) }
    var typeString: Data { data.subdata(in: 16..<30) }
    var rhu: UInt8 { data[30] }
    var magicBytesSize: UInt8 { data[31] }
    var magicBytes: Data { data.subdata(in: 32..<(32 + Int(magicBytesSize))) }
    var xorPad: Data { data.subdata(in: 48..<80) }
    
    init?(data: Data) {
        guard data.count == 80, data.startIndex == 0 else {
            return nil
        }
        guard data[31] <= 16 else {
            return nil // invalid magic byte size
        }
        self.data = data
        
    }
    func derivedKey(uid: Data, writeCounter: Data, salt: Data) -> DerivedTagKey {
        var seed = Data(typeString)
        seed.append( (writeCounter + Data(repeating: 0, count: 14))[0..<16 - magicBytesSize] )
        seed.append(magicBytes)
        seed.append(uid[0..<8])
        seed.append(uid[0..<8])
        seed.append(contentsOf: (0..<32).map { salt[$0] ^ xorPad[$0] })
        
        let output = hmac(seed: seed, iteration: 0) + hmac(seed: seed, iteration: 1)[0..<16]
        
        return DerivedTagKey(
            aesKey: output.subdata(in: 0..<16),
            aesIV: output.subdata(in: 16..<32),
            hmacKey: output.subdata(in: 32..<48)
        )
    }
    private func hmac(seed: Data, iteration: UInt8) -> Data {
        var hmac = CryptoKit.HMAC<SHA256>.init(key: SymmetricKey(data: hmacKey))
        let data = Data([(iteration >> 8) & 0x0f, (iteration >> 0) & 0x0f]) + seed
        hmac.update(data: data)
        return Data(hmac.finalize())
    }
}

struct DerivedTagKey {
    let aesKey: Data
    let aesIV: Data
    let hmacKey: Data
        
    func hmac(_ input: Data) -> Data {
        var hmac = CryptoKit.HMAC<SHA256>.init(key: SymmetricKey(data: hmacKey))
        hmac.update(data: input)
        return Data(hmac.finalize())
    }
    func decrypt(_ input: Data) throws ->  Data {
        let aes = try AES(key: [UInt8](aesKey), blockMode: CTR(iv: [UInt8](aesIV)))
        let output = try aes.decrypt([UInt8](input))
        return Data(output)
    }
}
