//
//  DataUploadController.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 20/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import Foundation
import UIKit

class DataUploadController: UITableViewController
{
    @IBOutlet var lastUploadData: UITextView!
    @IBOutlet var uploadStateLabel: UILabel!
    @IBOutlet var lastUploadLabel: UILabel!
    @IBOutlet var awsSecret: UITextField!
    @IBOutlet var awsBucket: UITextField!
    @IBOutlet var awsKeyID: UITextField!
    @IBOutlet var awsFile: UITextField!
    
    private var isAuthorised: Bool = false;
    
    override func loadView()
    {
        super.loadView();
        Task.init
        {
            let authStatus = await HealthKitWrapper.isAuthorised();
            if( authStatus )
            {
                await refreshData();
            }
            else
            {
                DispatchQueue.main.async
                {
                    self.throwErrorDialog(errorText: "Please configure HealthKit access first");
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        /*
        guard ( indexPath.section != 0 ) else
        {
            switch indexPath.row
            {
                case 0:
                    // Authorise HealthKit Button
                    guard isAuthorised else
                    {
                        updateLabelWithColour(path: IndexPath(row: 0, section: 0), colour: UIColor.secondaryLabel);
                        updateAccessoryWithActivityIndicator(path: IndexPath(row: 0, section: 0));
                        isAuthorised = true;
                        Task.init
                        {
                            do
                            {
                                try await HealthKitWrapper.authoriseHealthKit();
                                updateViewHealthKitAuthorised();
                            }
                            catch HealthKitWrapper.HealthKitSetupError.dataTypeNotAvailable
                            {
                                throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support the required data");
                                updateAccessoryWithNothing(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                updateLabelWithColour(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                isAuthorised = false;
                            }
                            catch HealthKitWrapper.HealthKitSetupError.notAvailableOnDevice
                            {
                                throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support HealthKit");
                                updateAccessoryWithNothing(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                updateLabelWithColour(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                isAuthorised = false;
                            }
                            catch
                            {
                                throwErrorDialog(errorText: "Authorization of HealthKit failed:\n\(error)");
                                updateAccessoryWithNothing(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                updateLabelWithColour(path: IndexPath(row: 0, section: 0), colour: UIColor.tintColor);
                                isAuthorised = false;
                            }
                        }
                        
                        return;
                    }
                break;
                case 1:
                    // Refresh Data
                    guard !isAuthorised else
                    {
                        updateLabelWithColour(path: IndexPath(row: 1, section: 0), colour: UIColor.secondaryLabel);
                        updateAccessoryWithActivityIndicator(path: IndexPath(row: 1, section: 0));
                        Task.init
                        {
                            await refreshData();
                            updateAccessoryWithNothing(path: IndexPath(row: 1, section: 0), colour: UIColor.tintColor);
                            updateLabelWithColour(path: IndexPath(row: 1, section: 0), colour: UIColor.tintColor);
                        }
                        
                        return;
                    }
                break;
                default:
                    return;
            }
            
            return;
        }*/
    }
    
    private func refreshData() async -> Void
    {
        let (minutes, steps, heartrate) = await HealthKitWrapper.refreshHealthKitData();
        DispatchQueue.main.async
        {
            

        }
    }
    
    private func throwErrorDialog(errorText: String)
    {
        let failedAlert = UIAlertController(title: "Error", message: errorText, preferredStyle: .alert);
        failedAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default));
        self.present(failedAlert, animated: true, completion: nil);
    }
    
    private func updateAccessoryWithActivityIndicator(path: IndexPath)
    {
        let healthKitCellWrap = tableView.cellForRow(at: path);
        if let healthKitCell = healthKitCellWrap
        {
            // Create the ActivityIndicatorView
            let activityIndicator = UIActivityIndicatorView();
            activityIndicator.frame = CGRect(x: 0, y: 0, width: 24, height: 24);
            
            // Bind the view to the TableCell Accessory
            healthKitCell.accessoryView = activityIndicator;
            healthKitCell.isUserInteractionEnabled = false;
            activityIndicator.startAnimating();
        }
    }
    
    private func updateAccessoryWithCheck(path: IndexPath, colour: UIColor)
    {
        let healthKitCellWrap = tableView.cellForRow(at: path);
        if let healthKitCell = healthKitCellWrap
        {
            healthKitCell.accessoryType = UITableViewCell.AccessoryType.checkmark;
            healthKitCell.isUserInteractionEnabled = false;
            healthKitCell.accessoryView = nil;
            healthKitCell.tintColor = colour;
            healthKitCell.isSelected = false;
        }
    }
    
    private func updateAccessoryWithNothing(path: IndexPath, colour: UIColor)
    {
        let healthKitCellWrap = tableView.cellForRow(at: path);
        if let healthKitCell = healthKitCellWrap
        {
            healthKitCell.accessoryType = UITableViewCell.AccessoryType.none;
            healthKitCell.isUserInteractionEnabled = true;
            healthKitCell.accessoryView = nil;
            healthKitCell.tintColor = colour;
            healthKitCell.isSelected = false;
        }
    }
    
    private func updateLabelWithColour(path: IndexPath, colour: UIColor)
    {
        let healthKitCellWrap = tableView.cellForRow(at: path);
        if let healthKitCell = healthKitCellWrap
        {
            if let cellLabel = healthKitCell.viewWithTag(1) as? UILabel
            {
                cellLabel.highlightedTextColor = colour;
                cellLabel.isHighlighted = false;
                cellLabel.textColor = colour;
            }
        }
    }
}
