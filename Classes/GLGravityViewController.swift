//
//  GLGravityViewController.swift
//  GLGravity
//
//  Created by 開発 on 2016/12/21.
//
//

import UIKit
import CoreMotion

class GLGravityViewController: UIViewController {
    @IBOutlet weak var glView: GLGravityView!
    private var manager: CMMotionManager = CMMotionManager()
    private var accel: [Double] = [0, 0, 0]
    
    // CONSTANTS
    final let kAccelerometerFrequency = 100.0 // Hz
    final let kFilteringFactor = 0.1
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        glView.startAnimation()
        
        //Configure and start accelerometer
        //http://d.hatena.ne.jp/hiroroEX/20130320/1363756687
        manager.accelerometerUpdateInterval = 1.0 / kAccelerometerFrequency
        manager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: accelerometerHandler)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        glView.stopAnimation()
        manager.stopAccelerometerUpdates()
    }
    
    
    private func accelerometerHandler(_ data: CMAccelerometerData?, error: Error?) {
        if error == nil {
            //Use a basic low-pass filter to only keep the gravity in the accelerometer values
            accel[0] = data!.acceleration.x * kFilteringFactor + accel[0] * (1.0 - kFilteringFactor)
            accel[1] = data!.acceleration.y * kFilteringFactor + accel[1] * (1.0 - kFilteringFactor)
            accel[2] = data!.acceleration.z * kFilteringFactor + accel[2] * (1.0 - kFilteringFactor)
            
            //Update the accelerometer values for the view
            glView.accel = accel
        } else {
            NSLog("accelerometer error: \(error!)")
        }
    }
    
}
