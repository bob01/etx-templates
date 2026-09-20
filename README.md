[![GitHub license](https://img.shields.io/github/license/bob01/etxwidgets)](https://github.com/bob01/etxwidgets/main/LICENSE)


# Welcome to etx-Templates for EdgeTX
**New model templates for our ELRS RotorFlight electric and nitro R/C Helicopters**<br>Thanks to Mike W. and Diego A. for the endless hours of testing and great ideas.

** USE AT YOUR OWN RISK **


### About etx-Templates
These templates have been created to quickly create new EdgeTx models for our standard ELRS RotorFlight configurations with all of the boilerplate stuff out of the way.
The idea is... 
- new model
- name it and maybe labels
- bind or assign a receiver ID if using model match
- customize widget settings, eg. battery warnings etc (or not)
- verify that all controls are correct and setup is SAFE
- GO FLY

Best used with [etx-presets (for RotorFlight)](https://github.com/bob01/etx-presets-rotorflight)

### Release notes
- 2026.05.06 - retain last values on disconnect (ePowerbar and eValue)
- 2026.04.21 - 2026 updates - many updates to support building single tx model screens for RotorFlight 2.3x+ and OMP OFS3 including...
  - ePowerbar - enchanements ported from ETHOS version
  - eBitmap - dynamic image selection based on RotorFlight craft name or cell count (1 - 4, 6)
  - eThrottle - renamed eStatus
  - eValue - new: same as stock Value widget + optional min / max fields
  - templates - Heli, Nitro Heli, OMP OFS3 - updated and simplified
  - model editor - gone.
  - docs are out of date but will catch up ... at some point
- 2026.03.19 - widgets revised for RotorFlight v2.3.x, EdgeTx 2.12.x+, RadioMaster TX16S MK3
  - find older RF-2.2.x, pre-EdgeTx 2.12.x, non-MK3 version here if needed<br>https://github.com/bob01/etx-templates/releases/tag/RF-2.2.x
- 2024.09.02 - revised for RotorFlight v2.1
- 2024.08.05 - ModelEditor - dropped BEC/ADC page - all current FC's have BEC ADCs now
- 2024.07.09 - eThrottle - Report "Bad Auto" + haptic if GOV reports LOST-HS ie bailout will not be available
- 2024.05.22 - v2.3 - model editor now sets the cell count setting of power bar widget, BEC voltage source defaults to servo bus telemetry sensor as more FC's are providing this sensor.
- 2024.05.15 - v2.1 - adjusted RPM tele ratio to 0 to address EdgeTx 2.10.0-rc4 to 2.10.0 release changes

### Requirements / dependencies
- RadioMaster Tx16s MK3 (maybe earlier models - untested)
- EdgeTx 2.12.x or later
- RotorFlight 2.3.x or later
- flight controller should have be prepared with [etx-presets (for RotorFlight)](https://github.com/bob01/etx-presets-rotorflight) or at a minimum the following telemetry sensors
  - ELRS: set telemetry_sensors = 1,3,4,5,6,7,11,12,13,14,15,21,22,27,28,42,43,46,50,60,88,89,90,91,93,95,96,0,0,0,0,0,0,0,0,0,0,0,0,0
  - FRSKY: set telemetry_sensors = 3,4,5,6,7,42,43,46,47,50,21,22,27,28,60,88,89,90,91,93,95,96,1,15,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0


### Features
- familiar helicopter radio look and feel
- familiar/practical main screen
- summary screen automatically displayed at end of the flight
- standard primary switch configurations (bank, safety, motor etc)
- configured telemetry sensors w/ recognizable names, units
- familiar mixer channel mappings
- logical switch and special functions implementing warnings, various telemetry monitoring
- optional switches for RF blackbox and EdgeTX SD logging
- 4 bank / profile configuration
- main screen uses etx-widgets (https://github.com/bob01/etx-widgets), included in this package

<img width="480" height="288" alt="image" src="https://github.com/user-attachments/assets/fb3c799b-f396-476d-ba02-baf4b0affae0" />
<img width="480" height="288" alt="image" src="https://github.com/user-attachments/assets/2e6118d0-a967-4b24-83fb-2121715f2638" />

<img width="480" height="288" alt="image" src="https://github.com/user-attachments/assets/7172eb3e-fc57-43d5-b589-fc47d864d6a1" />
<img width="480" height="288" alt="image" src="https://github.com/user-attachments/assets/12ec2756-f2ff-4c55-aaaa-ebaa90568e1a" />

## Start by creating a new model using the EdgeTx wizard...
![image](https://github.com/bob01/etx-templates/assets/4014433/6c40cca2-ba6b-4722-999c-26699aa36c75)
![image](https://github.com/bob01/etx-templates/assets/4014433/bae4309c-cc97-40b4-a1c3-5140f3279bce)
![image](https://github.com/bob01/etx-templates/assets/4014433/7cb186ef-f856-4b28-bccc-fc215e0d5c82)

### Name it, assign an image and maybe labels
![image](https://github.com/bob01/etx-templates/assets/4014433/c6f8e435-302c-49ac-9518-682418419e97)
![image](https://github.com/bob01/etx-templates/assets/4014433/b006d0b8-7ac9-46e7-8009-eee194809676)

### Bind or assign receiver ID, be sure to check your ELRS settings - eg.
![image](https://github.com/bob01/etx-templates/assets/4014433/3a12aeba-4a79-4b8d-9a39-4e1f0c40df98)
![image](https://github.com/bob01/etx-templates/assets/4014433/a85f8916-01f4-4b36-bb71-d6174ba2b0fe)
### Done.


### Installation
- download and unzip etx-templates-main.zip from (https://github.com/bob01/etx-templates)
![image](https://github.com/bob01/etx-templates/assets/4014433/69cd2a87-3844-4c5a-bf65-9464440fab54)
- connect the radio and copy the folders from the zip file to the radio
<img width="526" height="376" alt="image" src="https://github.com/user-attachments/assets/992fd774-2ba8-4fc0-bcae-5fdbee24786b" />


### Get a nice EdgeTX theme (optional)
- great collection of themes here - https://github.com/EdgeTX/themes
- theme "GrownUp" is an excellent choice - https://github.com/EdgeTX/themes/tree/main/THEMES/GrownUp
![image](https://github.com/bob01/etx-templates/assets/4014433/118c2040-597c-4bcb-88f9-2ce8f5d2a827)


### Enjoy.

