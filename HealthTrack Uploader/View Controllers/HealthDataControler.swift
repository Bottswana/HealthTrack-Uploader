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
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard ( indexPath.section != 0 ) else
        {
            switch indexPath.row
            {
                case 0:
                    // Authorise HealthKit
                    Task.init
                    {
                        do
                        {
                            try await HealthKitWrapper.authoriseHealthKit();
                            
                            

                        }
                        catch HealthKitWrapper.HealthKitSetupError.dataTypeNotAvailable
                        {
                            throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support the required data");
                        }
                        catch HealthKitWrapper.HealthKitSetupError.notAvailableOnDevice
                        {
                            throwErrorDialog(errorText: "Authorization of HealthKit failed:\nThis device does not support HealthKit");
                        }
                        catch
                        {
                            throwErrorDialog(errorText: "Authorization of HealthKit failed:\n\(error)");
                        }
                    }
                break;
                case 1:
                    // Refresh Data
                
                
                break;
                default:
                    return;
            }
            
            return;
        }
    }
    
    func throwErrorDialog(errorText: String)
    {
        let failedAlert = UIAlertController(title: "Error", message: errorText, preferredStyle: .alert);
        failedAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default));
        self.present(failedAlert, animated: true, completion: nil);
    }
}
