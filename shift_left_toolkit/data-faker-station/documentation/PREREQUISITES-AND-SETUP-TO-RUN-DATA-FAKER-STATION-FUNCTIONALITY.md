## Getting Started

Software to Install
* PowerShell 7 (and higher)
* Python 3
* Snowfakery

Troubleshooting Installation and Setup Process
* Troubleshooting PowerShell Default Windows Profile Settings

### PowerShell 
#### `***IMPORTANT`*** POWERSHELL NEEDS TO BE VERSION 7 AND HIGHER -- USE FOLLOWING COMMAND TO CONFIRM: `(Get-Host).Version`
   1. PowerShell GitHub repository - Installation instructions by operating system: https://github.com/powershell/powershell#get-powershell

### Python 3
   1. Download the latest version of python here: https://www.python.org/downloads/ 
      1. Be sure to select "Add to PATH" when prompted in the install/setup window
   1. After installing we will we will need to restart our machine
   1. Confirm successful install by opening up a terminal and typing "**python --version**"
 
for more info and documentation on Python: https://www.python.org/

### snowfakery 

   1. With python installed we can enter in a terminal "**pip install snowfakery**"
   1. Confirm successful install by typing in the terminal "**snowfakery --version**"

for more info and documentation on snowfakery: https://snowfakery.readthedocs.io/

### Troubleshooting PowerShell Default Windows Profile Settings

For Windows machines, an old version of PowerShell comes installed. We want to ensure the PowerShell 7 and higher (PowerShell core) is set as the PowerShell terminal used in VS Code. To confirm the latest PowerShell core path is open the command pallette by selecting "ctrl + shift + p" and type "Profile: Show Contents":

![image](https://user-images.githubusercontent.com/3968818/228069069-8640878a-e689-4789-b196-f6c7b52fa9c3.png)

A new side bard will show up on the left hand side and click on the settings.json file
         
![image](https://user-images.githubusercontent.com/3968818/228069353-e60b824e-c41e-4ee9-8242-302ea61d5194.png)

In the settings.json file, perform a local search by entering "ctrl + f" and type in "terminal.integrated.profiles.windows" and make sure the result shows the correct path the PowerShell core version installed on your machine:
 
![image](https://user-images.githubusercontent.com/3968818/228069790-cff81c5d-a1cd-4d26-9100-44764a0df9e3.png)

To change from the PowerShell executable path from Windows open up the command pallette by selecting "ctrl + shift + p" and type "Open User Settings (JSON)"
       
![image](https://user-images.githubusercontent.com/3968818/228068552-5f584a10-7f46-4ecd-8c88-ab1646d7a43f.png)

