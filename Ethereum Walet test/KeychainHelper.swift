//
//  KeychainHelper.swift
//  Ethereum Walet test
//
//  Created by admin on 02.05.2025.
//

import Foundation
import Security

class KeychainHelper {
    static func save(key: String, data: Data) -> Bool {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary

        SecItemDelete(query) // удалить старое
        return SecItemAdd(query, nil) == errSecSuccess
    }

    static func load(key: String) -> Data? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var result: AnyObject?
        if SecItemCopyMatching(query, &result) == errSecSuccess {
            return result as? Data
        }
        return nil
    }
}
