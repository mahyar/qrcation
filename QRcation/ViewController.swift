//
//  ViewController.swift
//  QRcation
//
//  Created by Mahyar McDonald on 4/23/16.
//  Copyright © 2016 Mahyar McDonald. All rights reserved.
//

import UIKit
import QRCode
import CoreLocation

struct PhotoInfo {
    let location : CLLocation
    let timestamp : NSDate
    
    static func makeTestInfo() -> PhotoInfo {
        let location = CLLocation(latitude: 52.5014787, longitude: 13.4358693)
        return PhotoInfo(location: location, timestamp: NSDate())
    }
}

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    lazy var imageView = UIImageView()
    lazy var infoLabel = UILabel()
    
    lazy var dateFormatter = NSDateFormatter()
    lazy var timer = NSTimer()
    
    lazy var locationManager = CLLocationManager()
    var lastLocation : CLLocation?
    
    // MARK: View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLocationManger()
        
        view.addSubview(imageView)
        
        view.addSubview(infoLabel)
        infoLabel.numberOfLines = 3
        infoLabel.text = "No Location Yet"
        
        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.timeStyle = .MediumStyle
        dateFormatter.locale = NSLocale.currentLocale()
        
        startTimer()
    }
    
    override func viewWillAppear(animated: Bool) {
        startTimer()
        registerAppLifecyleNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        stopTimer()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        let width = view.bounds.size.width
        
        imageView.center = view.center
        let sq = imageWidth()
        imageView.bounds = CGRectMake(0, 0, sq, sq)
        
        infoLabel.frame = CGRectMake(10, 40, width-20, 25*3)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: App Lifecycle
    
    func registerAppLifecyleNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.appBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.appForeground), name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    func appBackground() {
        stopTimer()
    }
    
    func appForeground() {
        startTimer()
    }
    
    // MARK: Location Stuff
    
    func setupLocationManger() {
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.desiredAccuracy = 100
        locationManager.distanceFilter = 100
        
        if CLLocationManager.authorizationStatus() == .NotDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            if CLLocationManager.locationServicesEnabled() {
                locationManager.startUpdatingLocation()
            } else {
                NSLog("Services Not enabled")
            }
        }
        
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus)
    {
        if status == .AuthorizedAlways || status == .AuthorizedWhenInUse {
            manager.startUpdatingLocation()
        } else {
            NSLog("permission not allowed? status: \(status)")
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last {
            lastLocation = last
        }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        NSLog("location error: \(error)")
    }
    
    // MARK: QR Code Stuff
    
    func imageWidth() -> CGFloat {
        let sq = min(view.bounds.size.width,view.bounds.size.height)
        return sq
    }
    
    func stopTimer() {
        timer.invalidate()
    }
    
    func startTimer() {
        stopTimer()
        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(ViewController.timerBlip), userInfo: nil, repeats: true)
    }
    
    func timerBlip() {
        if let loc = lastLocation {
            updateCode(PhotoInfo(location: loc, timestamp: NSDate()))
        } else {
            infoLabel.text = "Location Missing"
        }
    }

    func updateCode(info : PhotoInfo) {
        //Anything involving views MUST be run on the main thread
        let imgWidth = imageWidth()
        let screenScale = UIScreen.mainScreen().scale
        
        //But generating images and such do not.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), {
            let latLongText = "\(info.location.coordinate.latitude), \(info.location.coordinate.longitude)"
            let smallLatLong = NSString(format:"%f, %f", info.location.coordinate.latitude,info.location.coordinate.longitude)
            
            let epochTime = UInt64(info.timestamp.timeIntervalSince1970*1000) //NSTimeInterval is a Double in seconds
            let formatTime = self.dateFormatter.stringFromDate(info.timestamp)
            
            let secondsInAHour = (60.0*60.0)
            let timezoneOffset = Double(NSTimeZone.localTimeZone().secondsFromGMT) / secondsInAHour
            let positiveSymbol = timezoneOffset > 0 ? "+" : ""
            let timezoneText = "\(positiveSymbol)\(timezoneOffset)"
            
            let qrText = "\(latLongText) \(epochTime) \(timezoneText)"
            let labelText = "LatLong: \(smallLatLong) \nTime: \(formatTime) \nTimezone: \(timezoneText)"
            
            let codeOpt = QRCode(qrText)
            var image : UIImage? = nil
            if var code = codeOpt {
                code.size = CGSize(width: imgWidth*screenScale,height: imgWidth*screenScale)
                image = code.image
            }

            //We are modifying views again, so back to the main thread it goes
            dispatch_async(dispatch_get_main_queue(), {
                self.infoLabel.text = labelText
                self.imageView.image = image
            })
        })
    }
}

