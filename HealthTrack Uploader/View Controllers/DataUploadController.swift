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
    @IBOutlet var ClearButtonCell: UITableViewCell!;
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
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UploadSettings");
        do
        {
            let appSettings = try storageContext.fetch(fetchRequest);
            if appSettings.count > 0
            {
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
        ClearButtonCell.isUserInteractionEnabled = false;
        syncButtonCell.isUserInteractionEnabled = false;
        
        // Check AWS Key ID
        guard let AWSKeyID = awsKeyID.text, AWSKeyID.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Key ID");
            ClearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check AWS Secret
        guard let AWSKeySecret = awsSecret.text, AWSKeySecret.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Secret");
            ClearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check Bucket Name
        guard let AWSBucket = awsBucket.text, AWSBucket.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Bucket Name");
            ClearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check File Name
        guard let FileName = awsFile.text, FileName.count > 0 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Filename");
            ClearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Check Interval
        guard let Interval = awsInterval.text, Interval.count > 0, let iInterval = Int(Interval), iInterval >= 1, iInterval <= 1440 else
        {
            self.throwErrorDialog(errorText: "Please provide a valid Sync Interval in minutes, between 1 and 1440");
            ClearButtonCell.isUserInteractionEnabled = true;
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
            self.throwErrorDialog(errorText: "Error saving App Data: \(error)");
            ClearButtonCell.isUserInteractionEnabled = true;
            syncButtonCell.isUserInteractionEnabled = true;
            clearCellAccessory(tableCell: saveButtonCell);
            return;
        }
        
        // Reset progress (Artificial delay as saving can be so quick the user gets no feedback)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            self.clearCellAccessory(tableCell: self.saveButtonCell);
            self.ClearButtonCell.isUserInteractionEnabled = true;
            self.syncButtonCell.isUserInteractionEnabled = true;
        }
    }
    
    @IBAction func resetSettings(_ sender: UIButton)
    {
        print("Pressed")
    }
    
    @IBAction func syncNow(_ sender: UIButton)
    {
        print("Pressed")
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
