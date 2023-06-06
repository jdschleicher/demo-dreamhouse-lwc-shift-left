* [Overview](#overview)
* [Important Files](#important-files)
* [Setting up and Running the Generate Recipes by Object Directory Command](#generate-recipes)
* [Preparing and Running the Apply Recipe File Command against a Target Salesforce Environment](#apply-recipe)
* [THINGS TO WATCH OUT FOR DRAFT]
* [Troulbeshooting]
* [Demo](#demo)
* [References, Snowfakery Recipe "One-Pager", and Supporting Documentation](#references)


***

### <a name="overview"></a>Overview

   "Org Data Seeding" is a Quality focused feature set to support the ability for a Product Team to ["Shift-Left"](https://devopedia.org/shift-left) and truly meet "Definition-of-Done". With this functionality it becomes possible to perform our user-story implementation work against an environment with production-like data. These recipes and data-sets located alongside the product code base in version control are what allow for data-faker-station to insert and upsert complex enterprise data relationships into any targeted environment. 

    Features:
    * Human readable YAML file provides definitions and direction on how to create data-sets
    * values for fields can be hard-coded or faked based on use case
    * Quick and scalable - 1000 records generated and inserted under a minute
    * Multiple recipes and associated data-sets created at once

***

### <a name="important-files"></a>Important Files

**recipe(s) file**

A yml/yaml file including specific data creation instructions for each object and associated field. These instructions are passed into snowfakery to generate the associated mock/fake data. Other notes to be aware of:
     
* There can be many recipe files based on the object relationships within a Product code base but only one can be process at a time. 
* Recipe files are generated and placed in a timestamped directory in the directory path "cicd_local/data-faker-station/inactive_recipes/generated_by_repository/**timestamp-folder-with-pattern-yyyyMMdd-HHmm**. This timestamp allows for recipes to be reused based on the timestamp.
* When looking to APPLY RECIPE FILE, pull a file from the inactive-recipes directory to the recipes directory

**config-data-seeding.json file**
 
This file shares important information about where the "GENERATE RECIPES BY OBJECTS DIRECTORY" functionality will be looking at when creating recipes based on the objects in the repository. There is also configuration properties that allow to reuse a previously generated set of data that was created and inserted to a target-org by the "APPLY RECIPE TO TARGET ORG" task. 

**OBJECT_BY_RELATIONSHIPS json file** 

This file includes a breakdown key/value map of objects to their associated relationship details and important child and parent count information, recipe faker values per field, and lookup details for associated fields that are lookup types

**RECIPES_BY_HIGHEST_PARENT_OBTRIARCH_TREELATIONSHIP json file** 

This file is generated from the details captured in the OBJECT_BY_RELATIONSHIPS json file. Using the information structure from the OBJECT_BY_RELATIONSHIPS we are able to sort the objects by those with the highest amount of child dependencies and then recursively process each object until we have a fully connected object family tree line for the highest parent known as the "ObjTriarch". There could be multiple recipe objtriarch family tree recipes files generated with each including its own objtriarch family "TreeLationship".


***

### <a name="generate-recipes"></a>Setting up and Running the Generate Recipes by Object Directory Command

As long as our expected target environment as been authenticated against and an alias created for that authentication then there is little to do from there.

   1. Make sure all necessary software is installed on your machine: [Software Install and Pre-Steps](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/wiki/PREREQUISITES-AND-SETUP-TO-RUN-DATA-FAKER-STATION-FUNCTIONALITY)
   1. Ensure the **[cicd_local](https://github.com/department-of-veterans-affairs/va-salesforce-dojo/tree/master/cicd_local)** directory from this repository is copied into the project we are working out of. 
   1. Ensure the **cicd_local/data-faker-station/config-data-seeding.json** file has the expected values for each json parameter. There is an option to re-use created data-sets as each "apply-data-config" run to perform data seeding creates a timestamped directory. If we want to re-use a specific directory to align with a specific user story or scenario, we can set the parameter **"use_existing"** to "true" and update the **"reuse_datetime_stamp"** to reflect the timestamped-directory that has the data-set we want to leverage.

     An example of what the "config-data-seeding.json" is below:
```yaml
    {
       "path_to_recipes": "recipes",
       "use_existing": "false",
       "path_to_generated_org_data_seeding": "generated-data-faker-station",
       "path_to_objects_directory": "sfdx-source/cicd-module/objects",
       "reuse_datetime_stamp": "20210902-0800"
    }
```

   4. Ensure we are running the powershell script from the root of our project.
   5. Ensure that the running user has Permission Sets Groups assigned to them to provide access to the objects in the data plan.
   6. If we need a recipe to start we can leverage the **Command Palette** by pressing the keyboard shortcut "ctrl + shift + P" or "command + shift + P" on a MAC and began typing into the input box "**Tasks: Run Task**". The dropdown/picklist will quickly search and filter up potential matches. We can use the down arrow to quickly go to the selection "Tasks: Run Task" the moment it shows up in the filter results. After that it will show up at the top of the filtered search items as recently used. Next we search for the built in task "GENERATE RECIPES BY OBJECTS DIRECTORY" form the .vscode/tasks.json file found in this va-salesforce-dojo repository.

        * The way the functionality works with "GENERATE RECIPES BY OBJECTS DIRECTORY" is that it leverages the config-data-seeding.json file listed above and the json property "path_to_objects_directory". Once that directory is set we the functionality will run as expected and create new recipe files based on the different object tree relationships in a timestamped directory under   

![image](https://user-images.githubusercontent.com/3968818/234380489-af961548-a8f8-4eae-ba64-d434cba43543.png)

![image](https://user-images.githubusercontent.com/3968818/234380827-9e31c78f-afe8-493b-9ff6-4d09ff8c5a17.png)



We can also leverage a terminal within the VS Code project. To run the script, enter the script file and pass in the alias of the targeted environment at the end as shown below.

* If we are using a poweshell terminal, the script command will be:
       
`.\cicd_local\data-faker-station\scripts\apply_data_config.ps1 target-alias`

* If we are using a bash terminal, the script command will be:
      
`pwsh cicd_local/data-faker-station/scripts/apply_data_config.ps1 target-alias`

***

### <a name="apply-recipe"></a>Preparing and Running the Apply Recipe File Command against a Target Salesforce Environment

In applying a recipe against a target environment there are some preparations to make to ensure we are setting up what we are expecting. There are some assumptions to start that direct the amount of objects created along with:
*   

***

### <a name="demo"></a>Demo - Video Link
  * [Org Data Seeding by Recipes(max.gov access required)](https://community.max.gov/download/attachments/2264273338/data-faker-station-seededrecord-example.mp4?version=1&modificationDate=1641828419569&api=v2) 
-- In the video, in confirming the newly inserted results in the developer console are difficult to view due to compressing the video to allow it to be uploaded to max.gov

***

### <a name="references"></a>References and Supporting Documentation

* [YAML Basics and Getting Started](https://www.cloudbees.com/blog/yaml-tutorial-everything-you-need-get-started)
* [Snowfakery Documentation](https://snowfakery.readthedocs.io/en/docs/index.html)
* [Snowfakery Recipe One-Pager](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/wiki/Snowfakery-Recipe-One-Pager)