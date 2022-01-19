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
  
    class func authoriseHealthKit() async throws -> Swift.Void
    {
        // See if we have HealthKit on the device we are running on
        guard HKHealthStore.isHealthDataAvailable() else
        {
            throw HealthKitSetupError.notAvailableOnDevice;
        }
        
        // See if we have the data types we are interested in
        guard let exerciseMinutes = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
              let restingHeart = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount)
        else
        {
            throw HealthKitSetupError.dataTypeNotAvailable;
        }
        
        // Setup access to HealthKit Data
        let healthKitTypesToRead: Set<HKSampleType> = [
            exerciseMinutes,
            restingHeart,
            stepCount
        ];

        try await HKHealthStore().__requestAuthorization(toShare: nil, read: healthKitTypesToRead);
    }
}
