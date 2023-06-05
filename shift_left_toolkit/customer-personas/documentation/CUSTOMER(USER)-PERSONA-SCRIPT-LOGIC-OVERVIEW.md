* ### PROCESS CUSTOMER(USER) PERSONA JSON FROM THE user-detail.json FILE

This functionality is responsible for capturing Salesforce specific IDs for the Permission Sets, Queues, Groups, and Profiles listed in the user-details.json. This is done by creating json files based off of the user-detail.json, holding expected structures and values that will be referenced in the additional functionality and associated logic. These structure files are created within a directory ".github-workflow-tmp" and these files can be referenced to ensure the map structures expected contain the correct Id's and not null values. 

* ### DEACTIvaTE EXISTING USERS
Ensures that previously existing Customer Personas with the same Username, that may have been previously added to the target scratch org, are deactivated and Username and name details adjusted to “inactive” titles. This ensures that the latest information is captured for the Customer Persona. This is a task important for integrated environments

* ### INSERT USERS
Leveraging the information given in the user-detail.json file, creates a Salesforce user representing each object entry in the user-detail.json file

* ### ASSIGN USERS PERMISSION SETS
Given the Permission Sets API names listed within the permset_api_names section of the user-detail.json file, the associated IDs are captured for those Permission Sets and mapped to their respective user. With this user-to-permissoin-sets structure in place, anonymous apex is ran adding each Permission Set to the user

* ### SET USER PASSWORDS	
In order to quickly login and experience the functionality of the new/updated feature with the expected Customer Persona, the login_url field in the user-detail.json file is populated for each user with a login link for the associated Customer Persona. A Team Member can click the link and immediately be directed to an open browser and logged into Salesforce as that Customer Persona.

* ### ADD USERS TO QUEUES
Given the Queues within the queue_api_names section, within each entry of the user-detail.json file, the associated IDs are captured for those Queues and mapped to their respective user. With this user-to-queues structure in place, anonymous apex is ran adding the user to each associated Queue

* ### ADD USERS TO GROUPS
Given the Groups within the group_api_names section, within each entry of the user-detail.json file, the associated IDs are captured for those Groups and mapped to their respective user. With this user-to-groups structure in place, anonymous apex is ran adding the user to each associated Group