//
//  HealthKitWrapper.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 18/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import HealthKit

class HealthKitWrapper
{
    enum HealthKitSetupError: Error
    {
        case notAvailableOnDevice
        case dataTypeNotAvailable
    }
    
    enum HealthKitQueryError: Error
    {
        case unknownError
    }
  
    class func authoriseHealthKit() async throws -> Swift.Void
    {
        // Fail if we dont have HealthKit on this device
        guard HKHealthStore.isHealthDataAvailable() else
        {
            throw HealthKitSetupError.notAvailableOnDevice;
        }
        
        // Request the data types we are interested in
        let dataTypes = try getDataTypes();
        try await HKHealthStore().__requestAuthorization(toShare: nil, read: dataTypes);
    }
    
    class func isAuthorised() async -> Bool
    {
        do
        {
            let dataTypes = try getDataTypes();
            let authorisationResult = try await HKHealthStore().statusForAuthorizationRequest(toShare: [], read: dataTypes);
            return authorisationResult == HKAuthorizationRequestStatus.unnecessary;
        }
        catch
        {
            return false;
        }
    }
    
    class func getSamplesForCurrentDay(dataType: HKQuantityType, options: HKStatisticsOptions? = nil) async throws -> HKStatistics
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
                    continuation.resume(throwing: HealthKitQueryError.unknownError);
                    return;
                }
                
                // Return data
                continuation.resume(returning: data)
            }
            
            // Execute Query
            HKHealthStore().execute(dataQuery);
        }
    }
    
    private class func getDataTypes() throws -> Set<HKSampleType>
    {
        guard let exerciseMinutes = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let restingHeart = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount)
        else
        {
            throw HealthKitSetupError.dataTypeNotAvailable;
        }
        
        return [
            exerciseMinutes,
            restingHeart,
            stepCount
        ];
    }
}
