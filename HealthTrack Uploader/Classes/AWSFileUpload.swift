//
//  AWSFileUpload.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 21/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import Foundation
import AWSCore
import AWSS3

class FileUploader
{
    private let storageContext: NSManagedObjectContext;
    private var lastUploadInfo: NSManagedObject;
    private let bucketName: String;
    private let fileName: String;
    
    enum FileUploaderError: Error
    {
        case invalidAWSConfig
        case invalidFileData
        case uploadFailed
        case unknownError
    }
    
    enum UploadState : Int16
    {
        case UploadComplete = 0
        case UploadFailed = 1
        case Unknown = 2
    }
    
    struct JSONDocument: Codable
    {
        var numberSteps: Double?
        var activeMinutes: Double?
        var restingHeartRate: Double?
        var uploadDate: Int64
        
        func encode(to encoder: Encoder) throws
        {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(numberSteps, forKey: .numberSteps)
            try container.encode(activeMinutes, forKey: .activeMinutes)
            try container.encode(restingHeartRate, forKey: .restingHeartRate)
            try container.encode(uploadDate, forKey: .uploadDate)
        }
    }
    
    init(storageContext: NSManagedObjectContext) throws
    {
        // Retrieve settings
        self.storageContext = storageContext;
        let settingsRequest = NSFetchRequest<NSManagedObject>(entityName: "UploadSettings");
        let uploadRequest = NSFetchRequest<NSManagedObject>(entityName: "LastUpload");
        var awsSettings: NSManagedObject? = nil;

        // Retrieve settings from CoreData
        let awsSettingsResult = try storageContext.fetch(settingsRequest);
        if awsSettingsResult.count > 0
        {
            awsSettings = awsSettingsResult[0];
        }
        
        // Retrieve last upload data
        let lastUploadResult = try storageContext.fetch(uploadRequest);
        if lastUploadResult.count > 0
        {
            lastUploadInfo = lastUploadResult[0];
        }
        else
        {
            let entity = NSEntityDescription.entity(forEntityName: "LastUpload", in: storageContext)!
            lastUploadInfo = NSManagedObject(entity: entity, insertInto: storageContext);
        }
        
        // Check we have valid credentials in CoreData
        guard let awsData = awsSettings,
              let awsKeyId = awsData.value(forKeyPath: "sAWSKeyID") as? String,
              let awsSecret = awsData.value(forKeyPath: "sAWSSecret") as? String,
              let awsFileName = awsData.value(forKeyPath: "sAWSFile") as? String,
              let awsBucketName = awsData.value(forKeyPath: "sAWSBucket") as? String else
        {
            throw FileUploaderError.invalidAWSConfig;
        }
        
        // Configure S3 Transfer Service
        let uploadConfig = AWSS3TransferUtilityConfiguration();
        uploadConfig.isAccelerateModeEnabled = false;
        self.bucketName = awsBucketName;
        self.fileName = awsFileName;
        
        // Configure AWS Service
        guard let _ = AWSS3TransferUtility.s3TransferUtility(forKey: "s3-upload") else
        {
            let credential = AWSStaticCredentialsProvider(accessKey: awsKeyId, secretKey: awsSecret);
            let awsConfig = AWSServiceConfiguration(region: .EUWest1, credentialsProvider: credential);
            AWSS3TransferUtility.register(with: awsConfig!, transferUtilityConfiguration: uploadConfig, forKey: "s3-upload");
            return;
        }
    }
    
    func uploadFile(uploadString: String) async throws -> Void
    {
        // Validate string and convert to data
        guard !uploadString.isEmpty, let data = uploadString.data(using: .utf8) else
        {
            throw FileUploaderError.invalidFileData;
        }
        
        return try await uploadFile(uploadData: data);
    }
    
    func uploadFile(uploadData: Data) async throws -> Void
    {
        // Validate Config
        guard let transferUtility = AWSS3TransferUtility.s3TransferUtility(forKey: "s3-upload") else
        {
            throw FileUploaderError.invalidAWSConfig;
        }
        
        // Begin transfer
        return try await withCheckedThrowingContinuation
        { continuation in
            
            // Define Completion Handler
            var block: AWSS3TransferUtilityUploadCompletionHandlerBlock?
            block = { (task, error) -> Void in
                if let errorMessage = error
                {
                    do
                    {
                        try self.updateLastUpload(uploadData: uploadData, errorMessage: errorMessage.localizedDescription);
                    }
                    catch
                    {
                        print("Unable to update CoreData with failed upload state")
                    }

                    print("S3 Upload Failed: \(errorMessage.localizedDescription)");
                    continuation.resume(throwing: FileUploaderError.uploadFailed);
                }
                else
                {
                    do
                    {
                        try self.updateLastUpload(uploadData: uploadData);
                    }
                    catch
                    {
                        print("Unable to update CoreData with successful upload state")
                    }
                    
                    print("S3 File Upload completed");
                    continuation.resume();
                }
                
                return;
            }
            
            transferUtility.uploadData(uploadData, bucket: bucketName, key: fileName, contentType: "application/json", expression: nil, completionHandler: block).continueWith
            {
                (task) -> AnyObject? in
                if let error = task.error
                {
                    do
                    {
                        try self.updateLastUpload(uploadData: uploadData, errorMessage: error.localizedDescription);
                    }
                    catch
                    {
                        print("Unable to update CoreData with failed upload state")
                    }

                    print("S3 Upload Task Failed: \(error.localizedDescription)");
                    continuation.resume(throwing: FileUploaderError.uploadFailed);
                }
                
                return nil;
            }
        }
    }
    
    func clearAWSConfig() -> Void
    {
        if let _ = AWSS3TransferUtility.s3TransferUtility(forKey: "s3-upload")
        {
            AWSS3TransferUtility.remove(forKey: "s3-upload");
        }
    }
    
    private func updateLastUpload(uploadData: Data, errorMessage: String? = nil) throws -> Void
    {
        let dataString = String(decoding: uploadData, as: UTF8.self);
        if let error = errorMessage
        {
            // Upload failed
            lastUploadInfo.setValue(UploadState.UploadFailed.rawValue, forKey: "iLastUploadState");
            lastUploadInfo.setValue(error, forKey: "sUploadResultDetail");
        }
        else
        {
            // Upload completed
            lastUploadInfo.setValue(UploadState.UploadComplete.rawValue, forKey: "iLastUploadState");
        }
        
        // Update common values
        lastUploadInfo.setValue(dataString, forKey: "sLastUploadData");
        lastUploadInfo.setValue(Date(), forKey: "dLastUploadTime");
        try storageContext.save();
    }
}
