* ### SCREEN RECORDING OF SCRIPT IN ACTION
  * [Customer(User) Persona screen recording](https://drive.google.com/file/d/1k9yvWEIAGdQ6yK58hFDcUqJX5FndcvNp/view)
    * Recording demonstrates activating and deactivating users with script within a scratch org 
    * There are 2 users within the user-detail.json file as part of demo which have their active boolean flags changed from true to false in hte demonstration to perform activation and deactivation of users based on the active field
  

* ### SYSTEM REQUIREMENTS FOR RUNNING CUSTOMER PERSONA CREATION SCRIPTS
  * Powershell 5.1 (Windows)
    * To Install: Installed by default on Windows systems
  * Powershell 7 (Mac)
    * To Install: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-macos?view=powershell-7.1

* ### ASSUMPTIONS 
  * The API names for Profiles, Permission Sets (Permission Set Groups can also be used), Groups, and Queues already exist in the target scratch org or sandbox the defaultusername alias represents
  * The username value is unique in the user-detail.json
  * the Email given for the user is accessible to the Team Member running the script.
     * *** This could also be a shared email address such as a Team directory for easy access to all team members***

* ### SCRIPT SETUP
  * The .sfdx\sfdx-config.json file has a "defaultusername" populated with an alias representing a target scratch org or sandbox we have authorized against with the sfdx cli on our local machine
  * cicd_local directory is at the base of the sfdx project directory structure
  * the user-detail.json file in cicd_local/user-personas directory is populated with an array of JSON objects with required details:  
    * [user-detail.json](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/blob/master/cicd_local/user-personas/user-detail.json)
  * There is a boolean field "active" on each Customer Persona structure in the user-detail.json file. If this value is set to true, the Customer Persona will be created on script run. This is required because scratch orgs can only have so many types of licenses per scratch org. For example, there are only 2 Salesforce licenses available and one is used as our System Administrator that is activated on scratch org creation. So if we have more than one Customer Persona that has a Profile that requires a Salesforce license, we can set only one Customer Persona active field to be true in order to perform testing for that specific Customer Persona. 
     * The current licenses usage information can be found in the scratch org/sandbox within Setup--> Company Information --> scroll down to the "User Licenses" section

* ### WHAT TO EXPECT AFTER THE CREATE CUSTOMER PERSONAS SCRIPT IS RAN
  * The login_url field in the user-detail.json file - This is an important feature of the Customer Persona creation functionality. After the script runs, the login_url will be populated with a URL that has the username and password information passed in as query parameters. This allows for an immediate login as a Customer Persona into the targeted environment and removing any steps and friction in testing as our expected Customer Persona.
    * For information on what will happen when ctrl + left-clicking the login_url and expected Salesforce login prompts go here: [LOGGING IN WITH "login_url"](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/wiki/LOGGING-IN-WITH-login_url)
  * There is a specific "triple-underscore" naming convention leveraged to flag certain User creation and deactivation scenarios against the targeted scratch org or sandbox. It appends to the username value in the user-detail.json a stripped version of the targeted URL.
