## Overview

- A SplitTunnel POC using Network Extension Transparent Proxy
- Note: This sample code project is associated with WWDC 2019 session [714: Network Extensions for Modern macOS](https://developer.apple.com/videos/play/wwdc19/714/)
- Example code from Apple on how to create a packet filter using network extensions: https://developer.apple.com/documentation/networkextension/filtering_network_traffic
- Check out PIA macOS Split Tunnelling document on Confluence

## Building

- Open xv_mac_split_tunnelling_poc/SplitTunnelProxy.xcodeproj using XCode.
- Check both targets Signing & Capabilities settings, making sure that:
	1. for both targets team is "Private Internet Access, Inc." (check Apple account certificates)
	2. target SplitTunnelProxy bundle identifier is "com.privateinternetaccess.vpn.splittunnel"
	3. target SplitTunnelProxyExtension bundle identifier is "com.privateinternetaccess.vpn.splittunnel"
- (optional) To change the debugging scheme settings click on the top center bar on SplitTunnelProxy, "Edit Scheme..."

### CI Building
To achieve runnable builds in GHA, we use the `build.sh` script. 
`build.sh` is written to be generic for any app+extension use-case, so we pass our specific values from environment variables.
To work on that script, modify `sample.env` and set the variables there for your specific development environment.

The aim is for `build.sh` to be as self-explanatory as possible, so prefer to document relevant things there.

## Debugging

- To debug the SplitTunnelProxy application select the  
  SplitTunnelProxy scheme and run it
- A UI will appear, click buttons to perform actions.
- Don't use the SplitTunnelProxyExtension scheme to launch  
  the project, the extension will be controlled by the app.
- To debug the extension, before launching the app click  
  Debug/Attach to process by PID or name...  
  enter this name "com.privateinter", select Debug as: Root  
  and click Attach.  
  The debugger will attach to the extension as soon as it starts.  
  Repeat this step for every debug session. 
- You can also attach the debugger to the extension using its PID.  
  Open the activity monitor, a process named  
  "com.privateinternetaccess.vpn.splittunnel" owned by root  
  should be present.  
  Check its PID, in XCode select "Debug" and "Attach to process  
  by PID or name...".

## Starting the proxy

Click the buttons in this sequence:  
"Activate", "loadOrInstallManager", "startProxy".

## Commands explanation

### activate
This will activate the network extension.  
A system popup will appear saying "System Extension Blocked".  
Open system settings/Security & Privacy and allow.  
Using the command `systemextensionsctl list` you can check the  
status of the extension:  
in the group --- com.apple.system_extension.network_extension  
the SplitTunnelProxyExtension should be present with the status: 
- [activated waiting for user] before allowing 
- [activated enabled] after allowing

This needs to run if the extension code has been modified  
since the last execution

### loadOrInstallManager
This will either load any existing configuration or create a new one. 

### startProxy
When the configuration has been created for the first time and the  
proxy is started, a system popup will be triggered with the message  
"“SplitTunnelProxy” Would Like to Add Proxy Configurations".  
Click Allow and check that "PIA Split Tunnel Proxy" vpn item is added  
in system settings/Network/VPN & Filters/Filters & Proxies  
and that the status is "Enabled".  
The root extension will be started and it possible to verify this  
using Activity monitor.  
Clicking this before activating the extension or loading the manager  
will result in an error.

### stopProxy
Stops the proxy extension, the root extension process will be killed.  
Bear in mind that this takes ~5 seconds.

### deactivate
This will uninstall the proxy configuration from the system.  
This is required only if the proxy configuration name has changed,  
otherwise calling activate again will be enough.
