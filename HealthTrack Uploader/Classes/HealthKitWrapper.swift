//
//  HealthKitWrapper.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 18/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import HealthKit
import CoreData

class HealthKitWrapper
{
    private static var healthKitMutex: NSLock = NSLock();
    private static var healthKitObservers: [HKObserverQuery] = [];
    private static var healthKitDataTypes: [HKQuantityType?] = [
        HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
        HKObjectType.quantityType(forIdentifier: .restingHeartRate),
        HKObjectType.quantityType(forIdentifier: .stepCount)
    ];
    
    /// Health Kit Wrapper Errors
    enum HealthKitError: Error
    {
        case HealthKitNotAvailable
        case DataTypeNotAvailable
        case NoDataTypeHandler
        case UnknownError
    }

    /// Request authorisation from the user to access HealthKit data.
    ///  Throws error if the OS returns a failure when requesting data
    ///  Note: Error response does not imply the user has denied access - In fact for privacy, the method will return normally even if the user refuses the requested access
    class func authoriseHealthKit() async throws -> Void
    {
        // Fail if we dont have HealthKit on this device
        guard HKHealthStore.isHealthDataAvailable() else
        {
            throw HealthKitError.HealthKitNotAvailable;
        }
        
        // Build a set of the types, checking none of them are nil
        var dataTypes : Set<HKSampleType> = Set();
        for hkQuantityType in healthKitDataTypes
        {
            guard hkQuantityType != nil else
            {
                throw HealthKitError.DataTypeNotAvailable;
            }
            
            dataTypes.insert(hkQuantityType! as HKSampleType);
        }
        
        // Request the data types we are interested in
        try await HKHealthStore().__requestAuthorization(toShare: nil, read: dataTypes);
    }
    
    /// Check if we have requested authorisation on this device before, or if we need to request it again
    /// Note: This method will return true if we have requested before, even if the user denied the request for privacy reasons.
    class func isAuthorised() async -> Bool
    {
        do
        {
            // Build a set of the types, checking none of them are nil
            var dataTypes : Set<HKSampleType> = Set();
            for hkQuantityType in healthKitDataTypes
            {
                guard hkQuantityType != nil else
                {
                    throw HealthKitError.DataTypeNotAvailable;
                }
                
                dataTypes.insert(hkQuantityType! as HKSampleType);
            }
            
            // Check to see if we have requested authorisation for those types before
            let authorisationResult = try await HKHealthStore().statusForAuthorizationRequest(toShare: [], read: dataTypes);
            return authorisationResult == HKAuthorizationRequestStatus.unnecessary;
        }
        catch
        {
            return false;
        }
    }
    
    /// Setup the HealthKit Sample Watchers and request backgroud delivery
    class func setupHealthKitObservers(storageContext: NSManagedObjectContext) async -> Void
    {
        // Check we are authorised and drop out if not
        let healthKitStore = HKHealthStore();
        guard await isAuthorised() else
        {
            return;
        }
        
        // Loop over each requested datatype and configure an observer for it
        for hkQuantityType in healthKitDataTypes
        {
            do
            {
                // Create observer
                let observer = HKObserverQuery(sampleType: hkQuantityType!, predicate: nil)
                { (query, completion, error) in
                    Task.init
                    {
                        do
                        {
                            print("Handling sample for \(hkQuantityType!.description)");
                            try await self.observerTriggered(storageContext: storageContext, sampleType: hkQuantityType!);
                        }
                        catch let error
                        {
                            print("Failed to handle sample for \(hkQuantityType!.description): \(error)");
                        }
                    }
                };
                
                // Execute observer
                //healthKitStore.execute(observer);
                healthKitObservers.append(observer);
                
                // Request background delivery
                try await healthKitStore.enableBackgroundDelivery(for: hkQuantityType!, frequency: HKUpdateFrequency.hourly);
                print("Configured Observer and BackgroundDelivery for \(hkQuantityType!.description)");
            }
            catch let error
            {
                print("Failed to configure Observer and BackgroundDelivery for \(hkQuantityType!.description): \(error)");
            }
        }
    }
    
    /// Get Real-Time Non Cached data from the HealthKit store
    /// Note: This method will only work when the device is unlocked, so when the app is foreground and the user is interacting with it
    class func getRealTimeHealthData() async -> (activeMinutes: Double?, numberSteps: Double?, restingHeartRate: Double?)
    {
        return (await getExerciseMinutes(), await getStepCount(), await getRestingHeartrate());
    }
    
    /// Private: Called when an observer fires either foreground or background
    private class func observerTriggered(storageContext: NSManagedObjectContext, sampleType: HKQuantityType) async throws -> Void
    {
        // Update the respective sample in CoreData
        switch sampleType
        {
            case HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!:
                updateDataCache(storageContext: storageContext, exerciseMinutes: await getExerciseMinutes());
                break;
            case HKObjectType.quantityType(forIdentifier: .restingHeartRate)!:
                updateDataCache(storageContext: storageContext, restingHR: await getRestingHeartrate());
                break;
            case HKObjectType.quantityType(forIdentifier: .stepCount)!:
                updateDataCache(storageContext: storageContext, stepCount: await getStepCount());
                break;
            default:
                throw HealthKitError.NoDataTypeHandler;
        }
        
        // Trigger a file upload
        healthKitMutex.lock();
        do
        {
            try await doDataUpload(storageContext: storageContext);
        }
        catch let error
        {
            print("Unable to upload to AWS: \(error)");
        }
        healthKitMutex.unlock();
    }
    
    /// Private: Called to update the HealthKit cached data in CoreData
    private class func updateDataCache(storageContext: NSManagedObjectContext, exerciseMinutes: Double? = nil, restingHR: Double? = nil, stepCount: Double? = nil)
    {
        var cacheData: NSManagedObject;
        do
        {
            // Retrieve cache data or make new instance
            let HKCacheDataRequest = NSFetchRequest<NSManagedObject>(entityName: "BGHKData");
            let HKCacheData = try storageContext.fetch(HKCacheDataRequest);
            if HKCacheData.count > 0
            {
                cacheData = HKCacheData[0];
            }
            else
            {
                let entity = NSEntityDescription.entity(forEntityName: "BGHKData", in: storageContext)!
                cacheData = NSManagedObject(entity: entity, insertInto: storageContext);
                cacheData.setValue(nil, forKey: "dExerciseMinutes");
                cacheData.setValue(nil, forKey: "dRestingHeartRate");
                cacheData.setValue(nil, forKey: "dStepCount");
            }
            
            // Update the cache data
            if( exerciseMinutes != nil ) { cacheData.setValue(exerciseMinutes, forKey: "dExerciseMinutes"); }
            if( restingHR != nil ) { cacheData.setValue(restingHR, forKey: "dRestingHeartRate"); }
            if( stepCount != nil ) { cacheData.setValue(stepCount, forKey: "dStepCount"); }
            
            // Trigger CoreData save on main thread
            DispatchQueue.main.async
            {
                do
                {
                    try storageContext.save();
                }
                catch
                {
                    print("Unable to save CoreData from background task: \(error)");
                }
            }
        }
        catch
        {
            print("Unable to update CoreData from background task: \(error)");
        }
    }
    
    /// Private: Called to upload data to AWS
    private class func doDataUpload(storageContext: NSManagedObjectContext) async throws -> Void
    {
        // Perform the background work
        let uploadClass = try FileUploader(storageContext: storageContext);
        var restingHeartRate: Double? = nil;
        var activeMinutes: Double? = nil;
        var numberSteps: Double? = nil;
        
        // Retrieve cached data from CoreData
        // We can't fetch HK data directly in the background as the device may be locked
        // and the HealthKit store is unavailable when the device is locked
        let HKCacheDataRequest = NSFetchRequest<NSManagedObject>(entityName: "BGHKData");
        let cacheDataResult = try storageContext.fetch(HKCacheDataRequest);
        if cacheDataResult.count > 0
        {
            restingHeartRate = cacheDataResult[0].value(forKeyPath: "dRestingHeartRate") as? Double;
            activeMinutes = cacheDataResult[0].value(forKeyPath: "dExerciseMinutes") as? Double;
            numberSteps = cacheDataResult[0].value(forKeyPath: "dStepCount") as? Double;
        }
        
        // Perform the data upload
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

        // Create AWS class and trigger upload
        try await uploadClass.uploadFile(uploadData: jsonData);
    }
    
    /// Private: Returns samples for the current day for the requested data type
    private class func getSamplesForCurrentDay(dataType: HKQuantityType, options: HKStatisticsOptions? = nil) async throws -> HKStatistics
    {
        // Setup the scope for our samples
        let timeNow = Date();
        let mostRecentPredicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: timeNow), end: timeNow, options: .strictEndDate);
    
        // Convert continuation based api to modern standards
        return try await withCheckedThrowingContinuation
        { continuation in
            let dataQuery = HKStatisticsQuery(quantityType: dataType, quantitySamplePredicate: mostRecentPredicate, options: options ?? [])
            { (_, dataWrapped, error) in
                guard let data = dataWrapped else
                {
                    // Error in continuation
                    if let errorunwrap = error
                    {
                        continuation.resume(throwing: errorunwrap);
                        return;
                    }
                    
                    // Unable to unwrap error
                    continuation.resume(throwing: HealthKitError.UnknownError);
                    return;
                }
                
                // Return data
                continuation.resume(returning: data)
            }
            
            // Execute Query
            HKHealthStore().execute(dataQuery);
        }
    }
    
    /// Private: Get the current exercise minutes
    private class func getExerciseMinutes() async -> Double?
    {
        do
        {
            let exersiseTimeTypeWrapped = HKObjectType.quantityType(forIdentifier: .appleExerciseTime);
            if let exersiseTimeType = exersiseTimeTypeWrapped
            {
                let queryResult = try await getSamplesForCurrentDay(dataType: exersiseTimeType, options: .cumulativeSum);
                let todaysSampleWrapped = queryResult.sumQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.minute());
                    return rawValue;
                }
            }
        }
        catch {}
        return nil;
    }
    
    /// Private: Get the current step count
    private class func getStepCount() async -> Double?
    {
        do
        {
            let stepCountTypeWrapped = HKObjectType.quantityType(forIdentifier: .stepCount);
            if let stepCountType = stepCountTypeWrapped
            {
                let queryResult = try await getSamplesForCurrentDay(dataType: stepCountType, options: .cumulativeSum);
                let todaysSampleWrapped = queryResult.sumQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.count());
                    return rawValue;
                }
            }
        }
        catch {}
        return nil;
    }
    
    /// Private: Get the current resting heartrate
    private class func getRestingHeartrate() async -> Double?
    {
        do
        {
            let restingHRTypeWrapped = HKObjectType.quantityType(forIdentifier: .restingHeartRate);
            if let restingHRType = restingHRTypeWrapped
            {
                let queryResult = try await getSamplesForCurrentDay(dataType: restingHRType, options: .discreteAverage);
                let todaysSampleWrapped = queryResult.averageQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.init(from: "count/min"));
                    return rawValue;
                }
            }
        }
        catch {}
        return nil;
    }
}
