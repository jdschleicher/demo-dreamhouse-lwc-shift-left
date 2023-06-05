* [Overview](#overview)
* [Important Files to Know](#files-to-know)
* [Setting up and Running the Script](#setup)
* [Demo](#demo)
* [References, Snowfakery Recipe "One-Pager", and Supporting Documentation](#references)


***

### <a name="overview"></a>Overview

   The intention behind an "automatically generated snowfakery recipe" is to remove some of the friction in learning the needed structure of YAML recipes as well as getting examples of snowfakery functions and syntax required in randomizing and faking the different Salesforce field-types. 

   We will first need to ensure we have object metadata in our local project which can easily be done with scratch orgs. With the exact object metadata files and associated markup pulled down from a scratch org, we can then run the "Generate Recipes by Repository" script which will parse all object metadata within our local project and create recipes in a specific custom and timestamped directory. These recipes can then be refined, committed, and leveraged by developers, admin, and QA alike to produce the intended data sets required to test a new User Story with Production-like data. 

***

### <a name="files-to-know">Important Files to Know

 - recipe file

    A "recipe" is a human-readable instruction that explains to a data annotator system how to annotate the data. A snowfakery recipe is a YAML file written with snowfakery specific annotations, syntax, and instruction to generate intended data sets. For our purposes this will be a Salesforce specific data set.

- OBJECT_BY_RELATIONSHIPS_yyyyMMdd-HHmm file

   The "OBJECT_BY_RELATIONSHIPS" file is a timestamped file that is an object-info artifact created following the completion of the "GENERATE RECIPES BY OBJECT DIRECTORY" command in the command pallette. 


***

### <a name="setup"></a>Setting up, Configuring, and Running the Script

As long as object metadata exists and is in source format in our local project there are minimal steps required in generating a snowfakery recipe that aligns exactly to the objects and associated field-types in our project.  

   1. Make sure all necessary software is installed on your machine: [Software Install and Pre-Steps](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/wiki/PREREQUISITES-AND-SETUP-TO-RUN-DATA-FAKER-STATION-FUNCTIONALITY)
   1. Ensure the **[cicd_local](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/tree/master/cicd_local)** directory from this repository is copied into the project we are working out of. 
   1. Ensure the **cicd_local/data-faker-station/config-data-seeding.json** file has the correct path for the eBikes_lue of the **path_to_objects_directory** json parameter. The structure we should be expecting as part of a eBikes_ project is "sfdx-source/name-of-package/objects". In a generated standard salesforce project generated with the Salesforce Extension Pack, the "path_to_objects_directory" eBikes_lue may be "force-app/default/main/objects". An example of what the "config-data-seeding.json" is below:
```yaml
    {
       "path_to_recipes": "recipes",
       "use_existing": "false",
       "path_to_generated_org_data_seeding": "generated-data-faker-station",
       "path_to_objects_directory": "sfdx-source/cicd-module/objects",
       "reuse_datetime_stamp": "20210902-0800"
    }
```

   1. Ensure we are running the powershell script from the root of our project. The simplest way to do this is to leverage a terminal within the VS Code project. 
  * If we are using a poweshell terminal, the script command will be:
       
        .\cicd_local\data-faker-station\scripts\main_generate_recipe_by_repository.ps1

  * If we are using a bash terminal, the script command will be:
       
        pwsh cicd_local/data-faker-station/scripts/main_generate_recipe_by_repository.ps1

***

### <a name="demo"></a>Demo - Video Link
  * [Generate Recipes by Repository Video Demo (max.gov access required)](https://community.max.gov/download/attachments/2264273338/generate-recipe-by-repository.mp4?version=1&modificationDate=1641293171246&api=v2)

***

### <a name="references"></a>References and Supporting Documentation

* [YAML Basics and Getting Started](https://www.cloudbees.com/blog/yaml-tutorial-everything-you-need-get-started)
* [Snowfakery Documentation](https://snowfakery.readthedocs.io/en/docs/index.html)
* [Snowfakery Recipe One-Pager](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/wiki/Snowfakery-Recipe-One-Pager)