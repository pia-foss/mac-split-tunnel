## Overview

- Note: This sample code project is associated with WWDC 2019 session [714: Network Extensions for Modern macOS](https://developer.apple.com/videos/play/wwdc19/714/)

## Building

- Open SplitTunnelMacOSPOC/SimpleFirewall.xcodeproj using XCode.
- Inside XCode click on SimpleFirewall (left bar with the app icon), SimpleFirewall.xcodeproj file will open in the editor.
- Check both targets Signing & Capabilities settings, make sure that:
	1. for both targets team is "Private Internet Access, Inc." (check Apple account certificates)
	2. target SimpleFirewall bundle identifier is "com.privateinternetaccess.splittunnel.poc"
	3. target SimpleFirewallExtension bundle identifier is "com.privateinternetaccess.splittunnel.poc.extension"
- (optional) To change the debugging scheme settings click on the top center bar on SimpleFirewall, "Edit Scheme..."

## Debugging

- To debug the SimpleFirewall application select the SimpleFirewall scheme in the top center bar and click the play button at the top of the left bar.
- A UI will appear, click buttons to perform actions.
- Don't use the SimpleFirewallExtension scheme to launch the project, the extension will be launched automatically by the app.
- To debug the extension, before launching the app click Debug/Attach to process by PID or name... enter this name "com.privateinter", select Debug as: Root and click Attach. Repeat everytime for every new debug session. 

## Starting the proxy

- Click in this sequence: "Activate", "loadManager", "makeManager", "startTunnel".

- "Activate"
  This will activate the network extension. A system popup will appear saying "System Extension Blocked". Open system settings/Security & Privacy, unlock at the left bottom and click Allow on "System software from application "SimpleFirewall.app" was blocked from loading.".
  Using the command "systemextensionsctl list" you can check the status of the extension: in the group --- com.apple.system_extension.network_extension the SimpleFirewallExtension should be present with the status [activated waiting for user] before allowing and [activated enabled] after allowing.
  Use this when extension has been modified since last execution (?)

- "loadManager"
  This will load any existing manager "MyTrasparentProxy" in system settings/Network.
  After this you can start the tunnel.

- "makeManager"
  This will trigger a system popup with this message "“SimpleFirewall” Would Like to Add Proxy Configurations".
  Open system settings/Network, click Allow and check that "MyTransparentProxy" vpn item is added and appear as Connected.
  This creates the NETransparentProxyManager object, saves the settings and call the startVPNTunnel function on the app side (ManagingExtension.swift), which triggers the startProxy function on the extension side (STProxyProvider.swift).
  Clicking this before activating the extension will result in an error.

- "startTunnel"
  calls the startVPNTunnel function, the vpn will appear as "Connected" again. 
  Will result in an error if called before loading or creating a new Manager.

- "stopTunnel"
  stops the tunnel, the vpn will appear as "Not Connected".

- "Deactivate"
  This will deactivate the network extension (not needed if it is the first time running the application), a system popup will be triggered asking for the user password. 
  This will reset the state of the extension, check also that no interfaces are present in system settings/Network, if there are click on them, click - and apply to remove them.

## Debugging the extension

- The debugger will be attached to the app when it is launched, perform all the steps to start the proxy.
- Open the activity monitor, a process named "com.privateinternetaccess.splittunnel.poc.extension" owned by user root should be present.
- Check its PID, in XCode select "Debug" and "Attach to process by PID or name...".
- Enter the PID and select "Debug Process As": root. Then click Attach.
- To check that it is working, create a breakpoint at the beginning of the stopProxy function, click "stopTunnel" and check that the breakpoint is triggered.
