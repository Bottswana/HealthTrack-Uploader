//
//  HealthDataController.swift
//  HealthTrack Uploader
//
//  Created by James Botting on 19/01/2022.
//  Copyright © 2022 Bottswana Media. All rights reserved.
//

import Foundation
import HealthKit
import UIKit

class HealthDataController: UITableViewController
{
    private var isAuthorised: Bool = false;
    
    override func loadView()
    {
        super.loadView();
        Task.init
        {
            let authStatus = await HealthKitWrapper.isAuthorised();
            if( authStatus )
            {
                // Update the view to match that we don't need to request authorisation again
                updateViewHealthKitAuthorised();
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
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
                        Task.init
                        {
                            let updateResults = await refreshHealthKitData();
                            print("Results: \(updateResults)");
                        }
                        
                        return;
                    }
                break;
                default:
                    return;
            }
            
            return;
        }
    }
    
    func refreshHealthKitData() async -> (activeMinutes: Double?, numberSteps: Double?, restingHeartRate: Double?)
    {
        var healthKitActiveMinutes: Double? = nil;
        var healthKitStepCount: Double? = nil;
        var healthKitRestingHR: Double? = nil;
        
        // Retrieve Exercise Minutes
        do
        {
            let exersiseTimeTypeWrapped = HKObjectType.quantityType(forIdentifier: .appleExerciseTime);
            if let exersiseTimeType = exersiseTimeTypeWrapped
            {
                let queryResult = try await HealthKitWrapper.getSamplesForCurrentDay(dataType: exersiseTimeType, options: .cumulativeSum);
                let todaysSampleWrapped = queryResult.sumQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.minute());
                    //print("HealthKitActiveMinutes: \(rawValue)");
                    healthKitActiveMinutes = rawValue;
                }
            }
        }
        catch
        {
            print("No samples for HealthKitActiveMinutes");
        }
        
        // Retrieve Step Count
        do
        {
            let stepCountTypeWrapped = HKObjectType.quantityType(forIdentifier: .stepCount);
            if let stepCountType = stepCountTypeWrapped
            {
                let queryResult = try await HealthKitWrapper.getSamplesForCurrentDay(dataType: stepCountType, options: .cumulativeSum);
                let todaysSampleWrapped = queryResult.sumQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.count());
                    //print("HealthKitStepCount: \(rawValue)");
                    healthKitStepCount = rawValue;
                }
            }
        }
        catch
        {
            print("No samples for HealthKitStepCount");
        }
        
        // Retrieve Avg Resting Heartrate
        do
        {
            let restingHRTypeWrapped = HKObjectType.quantityType(forIdentifier: .restingHeartRate);
            if let restingHRType = restingHRTypeWrapped
            {
                let queryResult = try await HealthKitWrapper.getSamplesForCurrentDay(dataType: restingHRType, options: .discreteAverage);
                let todaysSampleWrapped = queryResult.averageQuantity();
                if let todaysSample = todaysSampleWrapped
                {
                    let rawValue = todaysSample.doubleValue(for: HKUnit.init(from: "count/min"));
                    //print("HealthKitAvgHR: \(rawValue)");
                    healthKitRestingHR = rawValue;
                }
            }
        }
        catch
        {
            print("No samples for HealthKitAvgHR");
        }

        // Return data
        return (healthKitActiveMinutes, healthKitStepCount, healthKitRestingHR);
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
    
    private func updateViewHealthKitAuthorised()
    {
        // Update HealthKit button
        updateAccessoryWithCheck(path: IndexPath(row: 0, section: 0), colour: UIColor.secondaryLabel);
        updateLabelWithColour(path: IndexPath(row: 0, section: 0), colour: UIColor.secondaryLabel);
        
        // Update Sync Button
        updateAccessoryWithNothing(path: IndexPath(row: 1, section: 0), colour: UIColor.tintColor);
        updateLabelWithColour(path: IndexPath(row: 1, section: 0), colour: UIColor.tintColor);
        isAuthorised = true;
    }
}
