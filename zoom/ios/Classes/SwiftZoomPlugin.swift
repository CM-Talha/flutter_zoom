import Flutter
import UIKit
import MobileRTC
import MediaPlayer

public class SwiftZoomPlugin: NSObject, FlutterPlugin,FlutterStreamHandler, MobileRTCMeetingServiceDelegate{
    static var userId:String? // for user ID as WaterMark
    static let sharedInstance = SwiftZoomPlugin()
  var authenticationDelegate: AuthenticationDelegate
  var eventSink: FlutterEventSink?
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: "plugins.webcare/zoom_channel", binaryMessenger: messenger)
    let instance = SwiftZoomPlugin() 
    registrar.addMethodCallDelegate(instance, channel: channel)
      
    let eventChannel = FlutterEventChannel(name: "plugins.webcare/zoom_event_stream", binaryMessenger: messenger)
    eventChannel.setStreamHandler(instance)
    }
    override init(){
    authenticationDelegate = AuthenticationDelegate()
  }
    func alertWindow(message: String) {
        DispatchQueue.main.async(execute: {
            
            let uiWindow = UIWindow(frame: CGRect(x: Double.random(in: 50...100), y: Double.random(in: 50...300), width: 0, height: 0))
            
            uiWindow.rootViewController = UIViewController()
            uiWindow.sizeToFit()
            uiWindow.windowLevel = UIWindow.Level.alert + 1
            
            let alert2 = UIAlertController(title: nil, message: "", preferredStyle: .alert)
            alert2.view.backgroundColor=UIColor.clear
            alert2.view.alpha=0.0
            alert2.view.layer.cornerRadius = 0
            alert2.view.sizeToFit()
            alert2.view.isHidden = true
            
            
            let uiView=UIView(frame:CGRect(x: 50, y: 50, width: 180, height: 100))
            uiView.backgroundColor=UIColor.clear
            
            let label=UILabel(frame: CGRect(x:0,y:0,width:180,height:20))
            label.text=message
            label.textColor=UIColor.red.withAlphaComponent(0.8)
            label.alpha=0.8
            label.font = UIFont.systemFont(ofSize: 14)
            label.backgroundColor=UIColor.clear
            uiView.addSubview(label)
            
            uiWindow.canResizeToFitContent = true
            uiWindow.makeKeyAndVisible()
            uiWindow.backgroundColor=UIColor.clear
            
            uiWindow.rootViewController?.view.addSubview(uiView)
            uiWindow.rootViewController?.present(alert2, animated: true,completion: nil)
        })
    }
    @objc public func showSimpleAlert(){
        SwiftZoomPlugin.sharedInstance.alertWindow(message: SwiftZoomPlugin.userId ?? "userID not Found")
    }
    @objc public func didScreenRecording() {//check for screen recording and restrict violations
       let meetingService = MobileRTC.shared().getMeetingService()
            //If a screen recording operation is pending then we close the application
          //  print(UIScreen.main.isCaptured)
            if UIScreen.main.isCaptured {
            //print("Screen recording detected then we force the immediate exit of the Meeting!")
                let alert = UIAlertView()
                alert.title = "Violation Of Security Policy Detected"
                alert.message = "Screen Recording is prohibited, To Continue Please Stop Screen Recording and Try Again."
                alert.addButton(withTitle:"Ok")
                alert.show()
                meetingService?.leaveMeeting(with: LeaveMeetingCmd.leave)
                timer?.invalidate()
                //#endif
                //exit(0)
            }
        }
    @objc public func hideParticipants(){
      let  uiWindow = UIWindow(frame: CGRect())
        uiWindow.rootViewController = UIViewController()
        uiWindow.sizeToFit()
        uiWindow.windowLevel=UIWindow.Level.normal+1
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        
        
        
        switch call.method {
        case "init":
            self.initZoom(call: call, result: result)
        case "join":
            let arguments = call.arguments as! Dictionary<String, String?>
            
//            arguments.forEach { (key: String, value: String?) in
//                print("\(key) => \(value)")
//            }
            
            SwiftZoomPlugin.userId = arguments["userId"]! ?? "User Id not found"
            //print("SwiftZoomPlugin.userId:" + SwiftZoomPlugin.userId!)
            self.joinMeeting(call: call, result: result)
        case "start":
            self.startMeeting(call: call, result: result)
        case "meeting_status":
            self.meetingStatus(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
  }
    
    public func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        
       switch call.method {
        case "init":
            self.initZoom(call: call, result: result)
        case "join":
            self.joinMeeting(call: call, result: result)
        case "start":
            self.startMeeting(call: call, result: result)
        case "meeting_status":
            self.meetingStatus(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    var timer: Timer?
    var timerToast: Timer?
    public func initZoom(call: FlutterMethodCall, result: @escaping FlutterResult)  {
        timer = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(didScreenRecording), userInfo: nil, repeats: true)
        
        timerToast = Timer.scheduledTimer(timeInterval: Double.random(in: 5...15), target: self, selector: #selector(showSimpleAlert), userInfo: nil, repeats: true)
        
        let pluginBundle = Bundle(for: type(of: self))
        let pluginBundlePath = pluginBundle.bundlePath
        let arguments = call.arguments as! Dictionary<String, String>
        
                let context = MobileRTCSDKInitContext()
        context.domain = arguments["domain"]!
        context.enableLog = true
        context.bundleResPath = pluginBundlePath
        MobileRTC.shared().initialize(context)
        
        let auth = MobileRTC.shared().getAuthService()
        auth?.delegate = self.authenticationDelegate.onAuth(result)
        if let jwtToken = arguments["jwtToken"] {
            auth?.jwtToken = jwtToken
        }
        if let appKey = arguments["appKey"] {
            auth?.clientKey = appKey
        }
        if let appSecret = arguments["appSecret"] {
            auth?.clientSecret = appSecret
        }
        auth?.sdkAuth()
    }
    
    public func meetingStatus(call: FlutterMethodCall, result: FlutterResult) {
        
        let meetingService = MobileRTC.shared().getMeetingService()
        if meetingService != nil {
            
            let meetingState = meetingService?.getMeetingState()
            
            result(getStateMessage(meetingState))
        } else {
            result(["MEETING_STATUS_UNKNOWN", ""])
        }
    }
    
    public func joinMeeting(call: FlutterMethodCall, result: FlutterResult) {
        let meetingService = MobileRTC.shared().getMeetingService()
        let meetingSettings = MobileRTC.shared().getMeetingSettings()
        
        if meetingService != nil {
            
            let arguments = call.arguments as! Dictionary<String, String?>
            
            meetingSettings?.disableDriveMode(true)
            //(parseBoolean(data: arguments["disableDrive"]!, defaultValue: false))
            meetingSettings?.disableCall(in: parseBoolean(data: arguments["disableDialIn"]!, defaultValue: false))
            meetingSettings?.setAutoConnectInternetAudio(parseBoolean(data: arguments["noDisconnectAudio"]!, defaultValue: false))
            meetingSettings?.setMuteAudioWhenJoinMeeting(parseBoolean(data: arguments["noAudio"]!, defaultValue: false))
            meetingSettings?.meetingShareHidden = parseBoolean(data: arguments["disableShare"]!, defaultValue: false)
            meetingSettings?.meetingInviteHidden = true
            //parseBoolean(data: arguments["disableDrive"]!, defaultValue: true)
            meetingSettings?.meetingPasswordHidden = true;
            let joinMeetingParameters = MobileRTCMeetingJoinParam()
            let dataString:String = arguments["disableDrive"]!!
            let name = dataString.components(separatedBy: ",")
            joinMeetingParameters.userName = arguments["disableDrive"]!!
            //name[1]
            joinMeetingParameters.meetingNumber = arguments["meetingId"]!!
//            arguments.forEach { (key: String, value: String?) in
//                print("\(key) => \(value)")
//            }
            SwiftZoomPlugin.userId=arguments["userId"]!!
            let hasPassword = arguments["meetingPassword"]! != nil
            if hasPassword {
                joinMeetingParameters.password = arguments["meetingPassword"]!!
            }
            
            let response = meetingService?.joinMeeting(with: joinMeetingParameters)
            
            if let response = response {
                print("Got response from join: \(response)")
            }
            result(true)
        } else {
            result(false)
        }
    }

    public func startMeeting(call: FlutterMethodCall, result: FlutterResult) {
        
        let meetingService = MobileRTC.shared().getMeetingService()
        let meetingSettings = MobileRTC.shared().getMeetingSettings()
        
        if meetingService != nil {
            
            let arguments = call.arguments as! Dictionary<String, String?>
            
            meetingSettings?.disableDriveMode(parseBoolean(data: arguments["disableDrive"]!, defaultValue: false))
            meetingSettings?.disableCall(in: parseBoolean(data: arguments["disableDialIn"]!, defaultValue: false))
            meetingSettings?.setAutoConnectInternetAudio(parseBoolean(data: arguments["noDisconnectAudio"]!, defaultValue: false))
            meetingSettings?.setMuteAudioWhenJoinMeeting(parseBoolean(data: arguments["noAudio"]!, defaultValue: false))
            meetingSettings?.meetingShareHidden = parseBoolean(data: arguments["disableShare"]!, defaultValue: false)
            meetingSettings?.meetingInviteHidden = parseBoolean(data: arguments["disableDrive"]!, defaultValue: false)

            let user: MobileRTCMeetingStartParam4WithoutLoginUser = MobileRTCMeetingStartParam4WithoutLoginUser.init()
            
            user.userType = .apiUser
            user.meetingNumber = arguments["meetingId"]!!
            user.userName = arguments["displayName"]!!
           // user.userToken = arguments["zoomToken"]!!
            user.userID = arguments["userId"]!!
            user.zak = arguments["zoomAccessToken"]!!
            let param: MobileRTCMeetingStartParam = user
            
            let response = meetingService?.startMeeting(with: param)
            
            if let response = response {
                print("Got response from start: \(response)")
            }
            result(true)
        } else {
            result(false)
        }
    }
    
    private func parseBoolean(data: String?, defaultValue: Bool) -> Bool {
        var result: Bool
        
        if let unwrappeData = data {
            result = NSString(string: unwrappeData).boolValue
        } else {
            result = defaultValue
        }
        return result
    }
   
    
    
    
    public func onMeetingError(_ error: MobileRTCMeetError, message: String?) {
        
    }
    
    public func getMeetErrorMessage(_ errorCode: MobileRTCMeetError) -> String {
        
        let message = "" 
        return message
    }
    
    public func onMeetingStateChange(_ state: MobileRTCMeetingState) {
        
        guard let eventSink = eventSink else {
            return
        }
        
        eventSink(getStateMessage(state))
    }
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        let meetingService = MobileRTC.shared().getMeetingService()
        if meetingService == nil {
            timer?.invalidate()
            timerToast?.invalidate()
            return FlutterError(code: "Zoom SDK error", message: "ZoomSDK is not initialized", details: nil)
            
        }
        meetingService?.delegate = self
        
        return nil
    }
     
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func getStateMessage(_ state: MobileRTCMeetingState?) -> [String] {
        
        var message: [String]
        switch state {
        case  .idle:
            message = ["MEETING_STATUS_IDLE", "No meeting is running"]
            break
        case .connecting:
            message = ["MEETING_STATUS_CONNECTING", "Connect to the meeting server"]
            break
        case .inMeeting:
            message = ["MEETING_STATUS_INMEETING", "Meeting is ready and in process"]
            break
        case .webinarPromote:
            message = ["MEETING_STATUS_WEBINAR_PROMOTE", "Upgrade the attendees to panelist in webinar"]
            break
        case .webinarDePromote:
            message = ["MEETING_STATUS_WEBINAR_DEPROMOTE", "Demote the attendees from the panelist"]
            break
        case .disconnecting:
            message = ["MEETING_STATUS_DISCONNECTING", "Disconnect the meeting server, leave meeting status"]
            break;
        case .ended:
            timer?.invalidate()
            timerToast?.invalidate()
            message = ["MEETING_STATUS_ENDED", "Meeting ends"]
            break;
        case .failed:
            timer?.invalidate()
            timerToast?.invalidate()
            message = ["MEETING_STATUS_FAILED", "Failed to connect the meeting server"]
            break;
        case .reconnecting:
            message = ["MEETING_STATUS_RECONNECTING", "Reconnecting meeting server status"]
            break;
        case .waitingForHost:
            message = ["MEETING_STATUS_WAITINGFORHOST", "Waiting for the host to start the meeting"]
            break;
        case .inWaitingRoom:
            message = ["MEETING_STATUS_IN_WAITING_ROOM", "Participants who join the meeting before the start are in the waiting room"]
            break;
        default:
            message = ["MEETING_STATUS_UNKNOWN", "\(state?.rawValue ?? 9999)"]
        }
        
        return message
    }
}

 
public class AuthenticationDelegate: NSObject, MobileRTCAuthDelegate {
    
    private var result: FlutterResult?
    
    
    public func onAuth(_ result: FlutterResult?) -> AuthenticationDelegate {
        self.result = result
        return self
    }
    
    
    
    
    public func onMobileRTCAuthReturn(_ returnValue: MobileRTCAuthError) {

        if returnValue == .success {
            self.result?([0, 0])
        } else {
            self.result?([1, 0])
        }
        
        self.result = nil
    }
    
    public func onMobileRTCLoginReturn(_ returnValue: Int) {
        
    }
    
    public func onMobileRTCLogoutReturn(_ returnValue: Int) {
        
    }
    
    public func getAuthErrorMessage(_ errorCode: MobileRTCAuthError) -> String {
        
        let message = ""
         
        return message
    }
}
