//
//  HealthTrack_UploaderApp.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 18/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import BackgroundTasks
import CoreData
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    var backgroundTask = BackgroundTask();
    lazy var persistentContainer: NSPersistentContainer =
    {
        let container = NSPersistentContainer(name: "HealthTrack Uploader")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error
            {
                fatalError("Unresolved error, \((error as NSError).userInfo)");
            }
        })
        
        return container;
    }()
    
    func applicationDidEnterBackground(_ application: UIApplication)
    {
        // Cancel any pending background tasks
        print("Application entered background state");
        backgroundTask.cancelAllPendingTasks();
        
        // Create a background persistentContext
        let backgroundContext = persistentContainer.newBackgroundContext();
        backgroundContext.automaticallyMergesChangesFromParent = true;
        
        // Schedule background task
        backgroundTask.scheduleAppRefresh(storageContext: backgroundContext);
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        backgroundTask.registerBackgroundTasks(storageContext: persistentContainer.viewContext);
        return true
    }
}
