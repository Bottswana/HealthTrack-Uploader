//
//  HealthDataController.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 19/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import Foundation
import UIKit

class HealthDataController: UITableViewController
{
    @IBOutlet var authoriseButtonCell: UITableViewCell!;
    @IBOutlet var refreshButtonCell: UITableViewCell!;
    @IBOutlet var restingHeartRate: UILabel!
    @IBOutlet var exerciseMinutes: UILabel!
    @IBOutlet var stepCount: UILabel!
    
    private var isAuthorised: Bool = false;
    
    override func loadView()
    {
        super.loadView();
        Task.init
        {
            let authStatus = await HealthKitWrapper.isAuthorised();
            if( authStatus )
            {
                // Already authorised
                updateCellAccessoryActivityIndicator(tableCell: authoriseButtonCell);
                clearCellAccessory(tableCell: refreshButtonCell);
                authoriseButtonCell.accessoryView = nil;
                isAuthorised = true;
                await refreshData();
            }
            else
            {
                // Not authorised
                updateCellAccessoryActivityIndicator(tableCell: refreshButtonCell);
                refreshButtonCell.accessoryView = nil;
            }
        }
    }
    
    @IBAction func authoriseHealthKit(_ sender: UIButton)
    {
        if !isAuthorised
        {
            // Clear the width autoresizing option and display a spinner in the accessory section of the table cell
            updateCellAccessoryActivityIndicator(tableCell: authoriseButtonCell);
            if (sender.autoresizingMask.rawValue & 2) != 0
            {
                sender.autoresizingMask = UIView.AutoresizingMask(rawValue: sender.autoresizingMask.rawValue - 2);
            }
            
            // Trigger HealthKit Authorisation
            isAuthorised = true;
            Task.init
            {
                do
                {
                    try await HealthKitWrapper.authoriseHealthKit();
                    clearCellAccessory(tableCell: refreshButtonCell);
                    authoriseButtonCell.accessoryView = nil;
                }
                catch HealthKitWrapper.HealthKitSetupError.dataTypeNotAvailable
                {
                    throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support the required data");
                    clearCellAccessory(tableCell: authoriseButtonCell);
                    isAuthorised = false;
                }
                catch HealthKitWrapper.HealthKitSetupError.notAvailableOnDevice
                {
                    throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support HealthKit");
                    clearCellAccessory(tableCell: authoriseButtonCell);
                    isAuthorised = false;
                }
                catch
                {
                    throwErrorDialog(errorText: "Authorization of HealthKit failed:\n\(error)");
                    clearCellAccessory(tableCell: authoriseButtonCell);
                    isAuthorised = false;
                }
            }
        }
    }
    
    @IBAction func refreshData(_ sender: UIButton)
    {
        if isAuthorised
        {
            // Clear the width autoresizing option and display a spinner in the accessory section of the table cell
            updateCellAccessoryActivityIndicator(tableCell: refreshButtonCell);
            if (sender.autoresizingMask.rawValue & 2) != 0
            {
                sender.autoresizingMask = UIView.AutoresizingMask(rawValue: sender.autoresizingMask.rawValue - 2);
            }
        
            // Refresh HealthKit Data
            Task.init
            {
                await refreshData();
                
                // Reset progress (Artificial delay as saving can be so quick the user gets no feedback)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
                {
                    // Return button to standard configuration
                    self.clearCellAccessory(tableCell: self.refreshButtonCell);
                }
            }
        }
    }
    
    private func refreshData() async -> Void
    {
        let (minutes, steps, heartrate) = await HealthKitWrapper.refreshHealthKitData();
        DispatchQueue.main.async
        {
            if let heartrate = heartrate { self.restingHeartRate.text = "\(Int(heartrate)) BPM"; }
            else { self.restingHeartRate.text = "No Data"; }
            
            if let steps = steps { self.stepCount.text = "\(Int(steps)) Steps"; }
            else { self.stepCount.text = "No Data"; }

            if let minutes = minutes { self.exerciseMinutes.text = "\(Int(minutes)) Minutes"; }
            else { self.exerciseMinutes.text = "No Data"; }
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
