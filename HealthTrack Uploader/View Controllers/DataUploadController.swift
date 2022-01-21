//
//  DataUploadController.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 20/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class DataUploadController: UITableViewController
{
    @IBOutlet var clearButtonCell: UITableViewCell!;
    @IBOutlet var syncButtonCell: UITableViewCell!;
    @IBOutlet var saveButtonCell: UITableViewCell!;
    @IBOutlet var lastUploadData: UITextView!
    @IBOutlet var uploadStateLabel: UILabel!
    @IBOutlet var lastUploadLabel: UILabel!
    @IBOutlet var awsInterval: UITextField!
    @IBOutlet var awsSecret: UITextField!
    @IBOutlet var awsBucket: UITextField!
    @IBOutlet var awsKeyID: UITextField!
    @IBOutlet var awsFile: UITextField!
    
    private var appSettings: NSManagedObject? = nil;
    private var isAuthorised: Bool = false;
    
    override func loadView()
    {
        super.loadView();

        // Retrieve CoreData
        let storageContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext;
        let settingsRequest = NSFetchRequest<NSManagedObject>(entityName: "UploadSettings");
        do
        {
            // Load AppSettings from CoreData
            let appSettings = try storageContext.fetch(settingsRequest);
            guard appSettings.count > 0 else
            {
                // Update UI to disable sync options when we do not have AWS configuration
                syncButtonCell.tintColor = UIColor.secondaryLabel;
                syncButtonCell.isUserInteractionEnabled = false;
                uploadStateLabel.text = "Not Configured";
                lastUploadLabel.text = "N/A";
                lastUploadData.text = "N/A";
                return;
            }
            
            // Update UI with AppSettings
            self.appSettings = appSettings[0];
            if let AWSKeyID = self.appSettings!.value(forKeyPath: "sAWSKeyID") as? String { self.awsKeyID.text = AWSKeyID; }
            else { self.awsKeyID.text = ""; }
            
            if let AWSSecret = self.appSettings!.value(forKeyPath: "sAWSSecret") as? String { self.awsSecret.text = AWSSecret; }
            else { self.awsSecret.text = ""; }
            
            if let AWSBucket = self.appSettings!.value(forKeyPath: "sAWSBucket") as? String { self.awsBucket.text = AWSBucket; }
            else { self.awsBucket.text = ""; }
            
            if let AWSFile = self.appSettings!.value(forKeyPath: "sAWSFile") as? String { self.awsFile.text = AWSFile; }
            else { self.awsFile.text = ""; }
            
            if let AWSInterval = self.appSettings!.value(forKeyPath: "iSyncInterval") as? Int16 { self.awsInterval.text = "\(AWSInterval)"; }
            else { self.awsInterval.text = ""; }
            
            // Reload upload status
            reloadStatus();
            
        }
        catch let error as NSError
        {
            guard error.description == "Foundation._GenericObjCError.nilError" else
            {
                self.throwErrorDialog(errorText: "Error retrieving App Data: \(error)");
                return;
            }
        }
    }
    
    // Save form changes to CoreData
    @IBAction func saveChanges(_ sender: UIButton)
    {
        // Clear the width autoresizing option and display a spinner in the accessory section of the table cell
        updateCellAccessoryActivityIndicator(tableCell: saveButtonCell);
        if (sender.autoresizingMask.rawValue & 2) != 0
        {
            sender.autoresizingMask = UIView.AutoresizingMask(rawValue: sender.autoresizingMask.rawValue - 2);
        }
        
        // Prevent user input to methods that could conflict while we are saving
        clearButtonCell.isUserInteractionEnabled = false;
        syncButtonCell.isUserInteractionEnabled = false;
        
        // Check AWS Key ID
        guard let AWSKeyID = awsKeyID.text, AWSKeyID.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Key ID");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check AWS Secret
        guard let AWSKeySecret = awsSecret.text, AWSKeySecret.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Secret");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check Bucket Name
        guard let AWSBucket = awsBucket.text, AWSBucket.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Bucket Name");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check File Name
        guard let FileName = awsFile.text, FileName.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Filename");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check Interval
        guard let Interval = awsInterval.text, Interval.count > 0, let iInterval = Int(Interval), iInterval >= 1, iInterval <= 1440 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Sync Interval in minutes, between 1 and 1440");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Get CoreData Context
        let storageContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext;
        if appSettings == nil
        {
            let entity = NSEntityDescription.entity(forEntityName: "UploadSettings", in: storageContext)!
            appSettings = NSManagedObject(entity: entity, insertInto: storageContext);
        }
        
        // Update appSettings
        appSettings!.setValue(AWSKeySecret, forKeyPath: "sAWSSecret");
        appSettings!.setValue(iInterval, forKeyPath: "iSyncInterval");
        appSettings!.setValue(AWSBucket, forKeyPath: "sAWSBucket");
        appSettings!.setValue(AWSKeyID, forKeyPath: "sAWSKeyID");
        appSettings!.setValue(FileName, forKeyPath: "sAWSFile");
        
        // Save changes
        do
        {
            try storageContext.save();
        }
        catch let error as NSError
        {
            self.throwErrorDialog(errorText: "Error saving AppData: \(error)");
            clearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Attempt to flush AWS Config if it exists
        do
        {
            let uploadClass = try FileUploader();
            uploadClass.clearAWSConfig();
        }
        catch
        {
            print("AWS config could not be flushed");
        }
        
        // Reset progress (Artificial delay as saving can be so quick the user gets no feedback)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            // Return 'Save Changes' button to standard configuration
            self.clearCellAccessory(tableCell: self.saveButtonCell);
            self.clearButtonCell.isUserInteractionEnabled = true;
            
            // Enable the Sync Options
            self.syncButtonCell.tintColor = .none;
            self.syncButtonCell.isUserInteractionEnabled = true;
            self.syncButtonCell.tintColor = .none;
            self.reloadStatus();
        }
    }
    
    @IBAction func resetSettings(_ sender: UIButton)
    {
        // Clear the width autoresizing option and display a spinner in the accessory section of the table cell
        updateCellAccessoryActivityIndicator(tableCell: clearButtonCell);
        if (sender.autoresizingMask.rawValue & 2) != 0
        {
            sender.autoresizingMask = UIView.AutoresizingMask(rawValue: sender.autoresizingMask.rawValue - 2);
        }
        
        // Prevent user input to methods that could conflict while we are saving
        saveButtonCell.isUserInteractionEnabled = false;
        syncButtonCell.isUserInteractionEnabled = false;
        
        // Get CoreData Context
        let storageContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext;
        guard let appSettings = appSettings else
        {
            saveButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: clearButtonCell);
            return;
        }
        
        // Delete settings data from CoreData
        do
        {
            do
            {
                // See if we have any data for a last upload attempt
                let uploadRequest = NSFetchRequest<NSManagedObject>(entityName: "LastUpload");
                let uploadData = try storageContext.fetch(uploadRequest);
                if uploadData.count > 0
                {
                    storageContext.delete(uploadData[0]);
                }
            }
            catch
            {
                print("No LastUpload element to delete from CoreData");
            }
            
            storageContext.delete(appSettings);
            try storageContext.save();
        }
        catch let error as NSError
        {
            self.throwErrorDialog(errorText: "Error clearing AppData: \(error)");
            saveButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: clearButtonCell);
            return;
        }
        
        // Attempt to flush AWS Config if it exists
        do
        {
            let uploadClass = try FileUploader();
            uploadClass.clearAWSConfig();
        }
        catch
        {
            print("AWS config could not be flushed");
        }
        
        // Reset progress (Artificial delay as saving can be so quick the user gets no feedback)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            // Return 'Reset Settings' button to standard configuration
            self.clearCellAccessory(tableCell: self.clearButtonCell);
            self.saveButtonCell.isUserInteractionEnabled = true;
            
            // Enable the Sync Options
            self.syncButtonCell.tintColor = UIColor.secondaryLabel;
            self.syncButtonCell.isUserInteractionEnabled = false;
            self.uploadStateLabel.text = "Not Configured";
            self.lastUploadLabel.text = "N/A";
            self.lastUploadData.text = "N/A";
            
            // Clear all the data in the AWS Fields
            self.awsInterval.text = "";
            self.awsSecret.text = "";
            self.awsBucket.text = "";
            self.awsKeyID.text = "";
            self.awsFile.text = "";
        }
    }
    
    @IBAction func syncNow(_ sender: UIButton)
    {
        // Clear the width autoresizing option and display a spinner in the accessory section of the table cell
        updateCellAccessoryActivityIndicator(tableCell: syncButtonCell);
        if (sender.autoresizingMask.rawValue & 2) != 0
        {
            sender.autoresizingMask = UIView.AutoresizingMask(rawValue: sender.autoresizingMask.rawValue - 2);
        }
        
        Task.init
        {
            // Create upload data structure
            let (activeMinutes, numberSteps, restingHeartRate) = await HealthKitWrapper.refreshHealthKitData();
            let jsonResults = FileUploader.JSONDocument(numberSteps: numberSteps, activeMinutes: activeMinutes, restingHeartRate: restingHeartRate);

            // Format data as a JSON String
            let encoder = JSONEncoder();
            encoder.outputFormatting = .prettyPrinted;
            let jsonData = try encoder.encode(jsonResults);

            do
            {
                // Create AWS class and trigger upload
                let uploadClass = try FileUploader();
                try await uploadClass.uploadFile(uploadData: jsonData);
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
                {
                    // Return 'Sync Now' button to standard configuration
                    self.clearCellAccessory(tableCell: self.syncButtonCell);
                    self.reloadStatus();
                }
            }
            catch
            {
                DispatchQueue.main.async
                {
                    let storageContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext;
                    let uploadRequest = NSFetchRequest<NSManagedObject>(entityName: "LastUpload");
                    do
                    {
                        // See if we can get a more useful error message
                        let uploadData = try storageContext.fetch(uploadRequest);
                        let uploadError = uploadData[0].value(forKeyPath: "sUploadResultDetail") as? String ?? error.localizedDescription;
                        self.throwErrorDialog(errorText: "Error uploading:\n\(uploadError)");
                    }
                    catch
                    {
                        // Show generic enum error message
                        self.throwErrorDialog(errorText: "Error uploading:\n\(error)");
                    }
                    
                    self.clearCellAccessory(tableCell: self.syncButtonCell);
                }
            }
        }
    }
    
    private func reloadStatus() -> Void
    {
        // Retrieve CoreData
        let storageContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext;
        let uploadRequest = NSFetchRequest<NSManagedObject>(entityName: "LastUpload");
        do
        {
            // See if we have any data for a last upload attempt
            let uploadData = try storageContext.fetch(uploadRequest);
            guard uploadData.count > 0 else
            {
                // No data from the background worker yet
                uploadStateLabel.text = "Waiting for background sync";
                lastUploadLabel.text = "No Data";
                lastUploadData.text = "No Data";
                return;
            }
            
            // Check the upload state
            let uploadResults = uploadData[0];
            guard let uploadStatus = uploadResults.value(forKeyPath: "iLastUploadState") as? Int16 else
            {
                uploadStateLabel.text = "Invalid Upload State";
                lastUploadLabel.text = "No Data";
                lastUploadData.text = "No Data";
                return;
            }
            
            // Update Data and Last Run time
            self.lastUploadData.text = uploadResults.value(forKeyPath: "sLastUploadData") as? String ?? "No Data";
            let dateResult = uploadResults.value(forKeyPath: "dLastUploadTime") as? Date;
            self.lastUploadLabel.text = dateResult?.formatted() ?? "No Data";

            // Populate status field
            let uploadResponse = FileUploader.UploadState(rawValue: uploadStatus) ?? FileUploader.UploadState.Unknown;
            switch uploadResponse
            {
                case FileUploader.UploadState.UploadFailed:
                    let uploadError = uploadResults.value(forKeyPath: "sUploadResultDetail") as? String ?? "No Data";
                    self.uploadStateLabel.text = "Failed: \(uploadError)";
                    return;

                case FileUploader.UploadState.UploadComplete:
                    self.uploadStateLabel.text = "Upload Successful";
                    return;

                default:
                    self.uploadStateLabel.text = "Invalid Upload State";
                    return;
            }
        }
        catch let error as NSError
        {
            guard error.description == "Foundation._GenericObjCError.nilError" else
            {
                self.throwErrorDialog(errorText: "Error retrieving App Data: \(error)");
                return;
            }
        }
    }
    
    private func throwErrorDialog(errorText: String)
    {
        let failedAlert = UIAlertController(title: "Error", message: errorText, preferredStyle: .alert);
        failedAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default));
        self.present(failedAlert, animated: true, completion: nil);
    }
    
    private func updateCellAccessoryActivityIndicator(tableCell: UITableViewCell)
    {
        // Create the ActivityIndicatorView
        let activityIndicator = UIActivityIndicatorView();
        activityIndicator.frame = CGRect(x: 0, y: 0, width: 24, height: 24);
        
        // Bind the view to the TableCell Accessory
        tableCell.tintColor = UIColor.secondaryLabel;
        tableCell.accessoryView = activityIndicator;
        tableCell.isUserInteractionEnabled = false;
        activityIndicator.startAnimating();
    }
    
    private func clearCellAccessory(tableCell: UITableViewCell)
    {
        // Clear the accessory type and reset the tint colour to default
        tableCell.accessoryType = UITableViewCell.AccessoryType.none;
        tableCell.isUserInteractionEnabled = true;
        tableCell.accessoryView = nil;
        tableCell.tintColor = .none;
    }
}
