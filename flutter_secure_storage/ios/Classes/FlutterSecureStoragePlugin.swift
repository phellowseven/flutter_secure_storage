//
//  FlutterSecureStoragePlugin.swift
//  flutter_secure_storage
//
//  Created by Julian Steenbakker on 23/11/2021.
//

//#import "FlutterSecureStoragePlugin.h"
import Flutter
import Foundation

let CHANNEL_NAME:String! = "plugins.it_nomads.com/flutter_secure_storage"

let InvalidParameters:String! = "Invalid parameter's type"


public class FlutterSecureStoragePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.addApplicationDelegate(FlutterSecureStoragePlugin(with: registrar))
    }
    

    private var query:NSDictionary!

    init() {
        self = super.init()
        if (self != nil) {
            // self.query = @{
            //               (__bridge id)kSecClass :(__bridge id)kSecClassGenericPassword,
            //               };
        }
        return self
    }

    class func registerWithRegistrar(registrar:NSObject!) {
        let channel:FlutterMethodChannel! = FlutterMethodChannel.methodChannelWithName(CHANNEL_NAME,
                                         binaryMessenger:registrar.messenger())
        let instance:FlutterSecureStoragePlugin! = FlutterSecureStoragePlugin()
        registrar.addMethodCallDelegate(instance, channel:channel)
    }

    func handleMethodCall(call:FlutterMethodCall!, result:FlutterResult) {
        let arguments:NSDictionary! = call.arguments()
        let options:NSDictionary! = (arguments["options"] is NSDictionary) ? arguments["options"] : nil
        let accountName:String! = options["accountName"]
        let groupId:String! = options["groupId"]
        let synchronizable:String! = options["synchronizable"]

        if ("read" == call.method) {
            let key:String! = arguments["key"]
            let value:String! = self.read(key, forGroup:groupId, forAccountName:accountName, forSynchronizable:synchronizable)

            result(value)
        } else if ("write" == call.method) {
            let key:String! = arguments["key"]
            let value:String! = arguments["value"]
            let accessibility:String! = options["accessibility"]

            if !(value is NSString) {
                result(InvalidParameters)
                return
            }

            self.write(value, forKey:key, forGroup:groupId, accessibilityAttr:accessibility, forAccountName:accountName, forSynchronizable:synchronizable)

            result(nil)
        } else if ("delete" == call.method) {
            let key:String! = arguments["key"]

            self.delete(key, forGroup:groupId, forAccountName:accountName, forSynchronizable:synchronizable)

            result(nil)
        } else if ("deleteAll" == call.method) {
            self.deleteAll(groupId, forAccountName:accountName, forSynchronizable:synchronizable)

            result(nil)
        } else if ("readAll" == call.method) {
            let value:NSDictionary! = self.readAll(groupId, forAccountName:accountName, forSynchronizable:synchronizable)

            result(value)
        } else if ("containsKey" == call.method) {
            let key:String! = arguments["key"]
            let containsKey:NSNumber! = self.containsKey(key, forGroup:groupId, forAccountName:accountName, forSynchronizable:synchronizable)

            result(containsKey)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    func write(value:String!, forKey key:String!, forGroup groupId:String!, accessibilityAttr accessibility:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) {
        let search:NSMutableDictionary! = self.query.mutableCopy()

        if groupId != nil {
            search[(kSecAttrAccessGroup as! id)] = groupId
        }

        if accountName != nil {
            search[(kSecAttrService as! id)] = accountName
        }

        search[(kSecAttrAccount as! id)] = key
        search[(kSecMatchLimit as! id)] = (kSecMatchLimitOne as! id)

        var attrSynchronizable:CFBooleanRef = kCFBooleanFalse
        if (synchronizable == "true") {
            attrSynchronizable = kCFBooleanTrue
        } else {
            attrSynchronizable = kCFBooleanFalse
        }
        search[(kSecAttrSynchronizable as! id)] = (attrSynchronizable as! id)

        // The default setting is kSecAttrAccessibleWhenUnlocked
        var attrAccessible:CFStringRef = kSecAttrAccessibleWhenUnlocked
        if accessibility != nil {
            if (accessibility == "passcode") {
                attrAccessible = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            } else if (accessibility == "unlocked") {
                attrAccessible = kSecAttrAccessibleWhenUnlocked
            } else if (accessibility == "unlocked_this_device") {
                attrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            } else if (accessibility == "first_unlock") {
                attrAccessible = kSecAttrAccessibleAfterFirstUnlock
            } else if (accessibility == "first_unlock_this_device") {
                attrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
        }

        var status:OSStatus
        status = SecItemCopyMatching((search as! CFDictionaryRef), nil)
        if status == noErr {
            search[(kSecMatchLimit as! id)] = nil

            let update:NSDictionary! = [
                // (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
                // (__bridge id)kSecAttrAccessible: (__bridge id) attrAccessible,
                // (__bridge id)kSecAttrSynchronizable: (__bridge id) attrSynchronizable,
            ]

            status = SecItemUpdate((search as! CFDictionaryRef), (update as! CFDictionaryRef))
            if status != noErr {
                NSLog("SecItemUpdate status = %d", (status as! int))
            }
        }else{
            search[(kSecValueData as! id)] = value.dataUsingEncoding(NSUTF8StringEncoding)
            search[(kSecMatchLimit as! id)] = nil
            // search[(__bridge id)kSecAttrAccessible] = (__bridge id) attrAccessible;

            status = SecItemAdd((search as! CFDictionaryRef), nil)
            if status != noErr {
                NSLog("SecItemAdd status = %d", (status as! int))
            }
        }
    }

    func read(key:String!, forGroup groupId:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) -> String! {
        let search:NSMutableDictionary! = self.query.mutableCopy()
        if groupId != nil {
         search[kSecAttrAccessGroup] = groupId
        }
        if accountName != nil {
            search[kSecAttrService ] = accountName
        }
        search[kSecAttrAccount] = key
        search[kSecReturnData ] = kCFBooleanTrue

        if (synchronizable == "true") {
            search[kSecAttrSynchronizable] = kCFBooleanTrue
        } else {
            search[kSecAttrSynchronizable] = kCFBooleanFalse
        }

        let resultData:CFData = nil

        var status:OSStatus
        status = SecItemCopyMatching((search as! CFDictionaryRef), (resultData as! CFTypeRef))
        var value:String!
        if status == noErr {
            let data:NSData! = resultData
            value = String(data:data as Data, encoding:String.Encoding.utf8)
        }

        return value
    }

    func delete(key:String!, forGroup groupId:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) {
        let search:NSMutableDictionary! = self.query.mutableCopy()
        if groupId != nil {
            search[(kSecAttrAccessGroup as! id)] = groupId
        }
        if accountName != nil {
            search[(kSecAttrService as! id)] = accountName
        }
        search[(kSecAttrAccount as! id)] = key
        search[(kSecReturnData as! id)] = (kCFBooleanTrue as! id)

        if (synchronizable == "true") {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanTrue as! id)
        } else {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanFalse as! id)
        }

        var status:OSStatus
        status = SecItemDelete((search as! CFDictionaryRef))
        if status != noErr {
            NSLog("SecItemDelete status = %d", (status as! int))
        }
    }

    func deleteAll(groupId:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) {
        let search:NSMutableDictionary! = self.query.mutableCopy()
        if groupId != nil {
            search[(kSecAttrAccessGroup as! id)] = groupId
        }
        if accountName != nil {
            search[(kSecAttrService as! id)] = accountName
        }
        if (synchronizable == "true") {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanTrue as! id)
        } else {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanFalse as! id)
        }
        var status:OSStatus
        status = SecItemDelete((search as! CFDictionaryRef))
        if status != noErr {
            NSLog("SecItemDeleteAll status = %d", (status as! int))
        }
    }

    func readAll(groupId:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) -> NSDictionary! {
        let search:NSMutableDictionary! = self.query.mutableCopy()
        if groupId != nil {
            search[(kSecAttrAccessGroup as! id)] = groupId
        }
        if accountName != nil {
            search[(kSecAttrService as! id)] = accountName
        }

        search[(kSecReturnData as! id)] = (kCFBooleanTrue as! id)

        search[(kSecMatchLimit as! id)] = (kSecMatchLimitAll as! id)
        search[(kSecReturnAttributes as! id)] = (kCFBooleanTrue as! id)

        if (synchronizable == "true") {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanTrue as! id)
        } else {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanFalse as! id)
        }

        let resultData:CFArrayRef = nil

        var status:OSStatus
        status = SecItemCopyMatching((search as! CFDictionaryRef), (&resultData as! CFTypeRef))
        if status == noErr {
            let items:[AnyObject]! = resultData

            let results:NSMutableDictionary! = NSMutableDictionary()
            for item:NSDictionary! in items {
                let key:String! = item[(kSecAttrAccount as! __bridge NSString)]
                let value:String! = String(data:item[(kSecValueData as! __bridge NSString)], encoding:NSUTF8StringEncoding)
                results[key] = value
             }
            return results.copy()
        }

        return []
    }

    func containsKey(key:String!, forGroup groupId:String!, forAccountName accountName:String!, forSynchronizable synchronizable:String!) -> NSNumber! {
        let search:NSMutableDictionary! = self.query.mutableCopy()
        if groupId != nil {
            search[(kSecAttrAccessGroup as! id)] = groupId
        }
        if accountName != nil {
            search[(kSecAttrService as! id)] = accountName
        }
        search[(kSecAttrAccount as! id)] = key
        search[(kSecReturnData as! id)] = (kCFBooleanTrue as! id)

        if (synchronizable == "true") {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanTrue as! id)
        } else {
            search[(kSecAttrSynchronizable as! id)] = (kCFBooleanFalse as! id)
        }

        if search.objectForKey(((kSecAttrAccount) as! id)) {
            return true
        } else {
            return false
        }
    }
}
