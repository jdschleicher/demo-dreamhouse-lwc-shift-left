## *** IMPORTANT *** 

When initially selecting the auto-login url, we will be prompted for specific verifications depending if we haven’t already logged in as that user on our machine. 

The prompts can be either:
* Verify Your Username: Verify we are logging in as someone we are expecting to. We can select “Don’t ask again on this device and then select “Continue”.
* Verify who you are by Email: At times, Salesforce will ask for verification by sending an email with a code to confirm we are who we say we are. The email added to the user-detail.json for that specific User Persona is the email address where we can grab this code from Salesforce
* Change Password: Once the confirmation and/or User Name verification is complete we will be asked to change our password. If we change the password in Salesforce the login_url in the user-detail.json will no longer work. We can get around this by selecting “Cancel” towards the bottom of the new-password form. 


