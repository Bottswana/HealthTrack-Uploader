//
//  HealthTrack_UploaderApp.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 18/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import CoreData
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    lazy var persistentContainer: NSPersistentContainer =
    {
        let container = NSPersistentContainer(name: "HealthTrack Uploader")
        container.loadPersistentStores(completionHandler:
        { (storeDescription, error) in
            if let error = error
            {
                fatalError("Unresolved error, \((error as NSError).userInfo)");
            }
        })
        
        return container;
    }()
    

    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        return true
    }
}
