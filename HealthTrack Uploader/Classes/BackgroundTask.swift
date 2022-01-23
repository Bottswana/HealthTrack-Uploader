//
//  BGTaskScheduler.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 21/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import BackgroundTasks
import Foundation
import CoreData
import UIKit

class BackgroundTask
{
    let bgTaskIdentifier: String = "com.bottswanamedia.awsuploader";
    
    func cancelAllPendingTasks()
    {
        print("Cancelling all pending background tasks");
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    
    func registerBackgroundTasks(storageContext: NSManagedObjectContext)
    {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskIdentifier, using: nil) { task in
            self.doUpload(task: task as! BGProcessingTask, storageContext: storageContext);
        }
    }
    
    func scheduleAppRefresh(storageContext: NSManagedObjectContext)
    {
        // Retrieve settings
        let settingsRequest = NSFetchRequest<NSManagedObject>(entityName: "UploadSettings");
        var appSettings: NSManagedObject? = nil;

        // Retrieve settings from CoreData
        do
        {
            let appSettingsResult = try storageContext.fetch(settingsRequest);
            if appSettingsResult.count > 0
            {
                appSettings = appSettingsResult[0];
            }
            
            // Check we have valid credentials in CoreData
            guard let refreshInterval = appSettings?.value(forKeyPath: "iSyncInterval") as? Int16 else
            {
                print("Unable to schedule refresh as iSyncInterval is invalid");
                return;
            }
            
            // Create Task
            let backgroundTask = BGProcessingTaskRequest(identifier: bgTaskIdentifier);
                backgroundTask.earliestBeginDate = Date(timeIntervalSinceNow: Double(refreshInterval) * 60);
                backgroundTask.requiresNetworkConnectivity = true;
                backgroundTask.requiresExternalPower = false;
            
            // Schedule Task
            print("Scheduled app refresh after a minimum of \(Double(refreshInterval) * 60) seconds");
            try BGTaskScheduler.shared.submit(backgroundTask);
        }
        catch
        {
            print("Unable to schedule refresh: \(error)");
            return;
        }
    }
    
    func doUpload(task: BGProcessingTask, storageContext: NSManagedObjectContext)
    {
        print("Performing Background Task");
        do
        {
            // Perform the background work
            let uploadClass = try FileUploader(storageContext: storageContext);
            let backgroundWork = Task.init
            {
                // Create upload data structure
                let (activeMinutes, numberSteps, restingHeartRate) = await HealthKitWrapper.refreshHealthKitData();
                let jsonResults = FileUploader.JSONDocument(
                    numberSteps: numberSteps,
                    activeMinutes: activeMinutes,
                    restingHeartRate: restingHeartRate,
                    uploadDate: Int64(Date().timeIntervalSince1970)
                );

                // Format data as a JSON String
                let encoder = JSONEncoder();
                encoder.outputFormatting = .prettyPrinted;
                let jsonData = try encoder.encode(jsonResults);

                do
                {
                    // Create AWS class and trigger upload
                    try await uploadClass.uploadFile(uploadData: jsonData);
                }
                catch
                {
                    print("Error on Background Task: \(error)");
                }
                
                // Mark task completed, schedule it again
                task.setTaskCompleted(success: true);
                DispatchQueue.main.async
                {
                    self.scheduleAppRefresh(storageContext: storageContext);
                }
            }
            
            // Define the method to abort if we run out of time
            task.expirationHandler =
            {
                // Cancel the task as it has taken too long
                print("Task is expiring, cancelling work");
                task.setTaskCompleted(success: false);
                backgroundWork.cancel();
                
                // Schedule it to run again another time
                self.scheduleAppRefresh(storageContext: storageContext);
            }
        }
        catch
        {
            print("Error on Background: \(error)");
        }
    }
}
