//
//  ContentView.swift
//  Ethereum Walet test
//
//  Created by admin on 02.05.2025.
//

import SwiftUI
import web3swift
import Web3Core
import BigInt

let apiKey : String = "<Your Key here>"

struct ContentView: View {
    @State private var walletAddress: String? = nil
    @State private var privateKey = ""
    @State private var balance: String? = nil
    
    @State private var toAddress = ""
    @State private var amount = ""
    @State private var message = ""
    
    var body: some View {
        NavigationView {
                Form {
                    Section("Wallet") {
                        VStack(alignment: .leading){
                            HStack{
                                Text("Адрес:")
                                Button("Copy") {
                                    UIPasteboard.general.string = walletAddress
                                }
                            }
                            Text("\(walletAddress ?? "Wallet not found")")
                                .font(.system(size: 10)).padding(.top, 4)
                        }
                        
                        VStack(alignment: .leading){
                            Text("Приватный ключ:")
                            Text("\(privateKey)")
                                .font(.system(size: 10)).padding(.top, 4)
                        }
                        
                        Text("Баланс: \(balance ?? "0")")
                        Button("Создать кошелёк") {
                            createWallet()
                        }
                    }
                    
                    Section("Transfer") {
                        TextField("Адрес получателя", text: $toAddress)
                        
                        TextField("Сумма (в ETH)", text: $amount)
                            .keyboardType(.decimalPad)
                        VStack{
                            Button("Отправить ETH") {
                                Task {
                                    await sendETH(to: toAddress, amount: amount)
                                }
                            }
                            .padding(.top, 4)
                            Text(message).foregroundColor(.blue)
                        }
                    }
                
            }
            .padding()
            .navigationTitle("Ethereum Wallet")
        }
        .onAppear() {
            loadWalletAddress()
        }
    }
    
    func loadWalletAddress(){
        guard let keyData = KeychainHelper.load(key: "eth_wallet"),
              let keystore = EthereumKeystoreV3(keyData),
              let walletAddress = keystore.addresses?.first?.address else {
            self.walletAddress = nil
            self.privateKey = ""
            return
        }
        self.walletAddress = walletAddress
        if let walletAddress = keystore.addresses?.first {
            let privateKeyData = try? keystore.UNSAFE_getPrivateKeyData(password: "123456", account: walletAddress)
            self.privateKey = privateKeyData?.toHexString() ?? ""
        }
    }
    
    func loadWalletBalance() async -> String {
        guard let keyData = KeychainHelper.load(key: "eth_wallet"),
              let keystore = EthereumKeystoreV3(keyData),
              let address = keystore.addresses?.first else {
            return "Кошелёк не знайдено"
        }

        // Підключення до Infura або іншого RPC
        guard let rpcURL = URL(string: "https://goerli.infura.io/v3/\(apiKey)") else {
            return "Помилка RPC URL"
        }

        let web3 = try! await Web3.new(rpcURL)

        do {
            let balanceResult = try await web3.eth.getBalance(for: address)
            let balanceInEth = Double(balanceResult) / pow(10, 18)
            return String(balanceInEth)
        } catch {
            return "Помилка: \(error.localizedDescription)"
        }
    }
    
    func createWallet() {
        do {
            let keystore = try EthereumKeystoreV3(password: "123456")!
            let address = keystore.addresses!.first!
            walletAddress = address.address
            
            let keyData = try JSONEncoder().encode(keystore.keystoreParams)
            if KeychainHelper.save(key: "eth_wallet", data: keyData) {
                print("Сохранено в Keychain")
            }
            
            let privateKeyData = try keystore.UNSAFE_getPrivateKeyData(password: "123456", account: address)
            privateKey = privateKeyData.toHexString()
            message = "Кошелёк создан"
        } catch {
            message = "Ошибка при создании: \(error.localizedDescription)"
        }
    }
    
    func ethToWei(_ ethString: String) -> BigUInt? {
        guard let ethDecimal = Decimal(string: ethString) else { return nil }
        let weiDecimal = ethDecimal * pow(10, 18)
        return BigUInt(weiDecimal.description)
    }
    
    func sendETH(to toAddress: String, amount: String) async {
        do {
            guard let keyData = KeychainHelper.load(key: "eth_wallet"),
                  let keystore = EthereumKeystoreV3(keyData),
                  let from = keystore.addresses?.first
            else {
                message = "Кошелёк не найден"
                return
            }
            
            guard let rpcUrl = URL(string: "https://goerli.infura.io/v3/\(apiKey)") else {
                message = "Неверный URL"
                return
            }
            
            let web3 = try await Web3.new(rpcUrl)
            web3.addKeystoreManager(KeystoreManager([keystore]))
            
            guard let toEthAddress = EthereumAddress(toAddress),
                  let ethValue = BigUInt(amount) else {
                message = "Неверный адрес или сумма"
                return
            }
            
            // Получаем текущую цену газа
            let gasPrice = try await web3.eth.gasPrice()
            
            // Создаем транзакцию
            var transaction = CodableTransaction(
                to: toEthAddress,
                value: ethValue,
                data: Data(),
                gasLimit: BigUInt(21000),
                gasPrice: gasPrice
            )
            
            // Устанавливаем адрес отправителя
            transaction.from = from
            
            // Получаем nonce для адреса
            let nonce = try await web3.eth.getTransactionCount(for: from, onBlock: .pending)
            transaction.nonce = nonce
            
            // Отправляем транзакцию
            let result = try await web3.eth.send(transaction)
            message = "Транзакция отправлена: \(result.hash)"
     
        } catch {
            message = "Ошибка: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
