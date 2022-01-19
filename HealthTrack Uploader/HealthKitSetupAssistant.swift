//
//  HealthKitSetupAssistant.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 18/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import HealthKit

class HealthKitSetupAssistant
{
    private enum HealthkitSetupError: Error
    {
        case notAvailableOnDevice
        case dataTypeNotAvailable
    }
  
    class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void)
    {
        // See if we have HealthKit on the device we are running on
        guard HKHealthStore.isHealthDataAvailable() else
        {
            completion(false, HealthkitSetupError.notAvailableOnDevice);
            return;
        }
        
        // Define what data we would like access to
        guard let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else
        {
            completion(false, HealthkitSetupError.dataTypeNotAvailable);
            return;
        }
        
        //3. Prepare a list of types you want HealthKit to read and write
        let healthKitTypesToRead: Set<HKSampleType> = [activeEnergy, HKObjectType.workoutType()];
        let healthKitTypesToWrite: Set<HKSampleType> = [];

        //4. Request Authorization
        HKHealthStore().requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead)
        {
            (success, error) in completion(success, error)
        }

        
        
        
    }
}
