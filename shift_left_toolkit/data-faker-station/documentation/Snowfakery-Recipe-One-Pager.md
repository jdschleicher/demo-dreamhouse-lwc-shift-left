
##  IMPORTANT 
In order for the snowfakery recipe to work as expected it must be in the correct [YAML Syntax](https://docs.fileformat.com/programming/yaml/#syntax)

***
### Snowfakery Documentation References

* [Snowfakery Central Concepts](https://snowfakery.readthedocs.io/en/latest/#central-concepts)
* [Index of Fake Data Types](https://snowfakery.readthedocs.io/en/latest/fakedata.html#index-of-fake-datatypes)
* [Snowfakery "Friends" - For every object Contact I create...](https://snowfakery.readthedocs.io/en/docs/index.html#friends)
* [Snowfakery "Relationships"](https://snowfakery.readthedocs.io/en/docs/index.html#relationships)
* [Snowfakery "date_between"](https://snowfakery.readthedocs.io/en/docs/index.html#date_between)

### Fake Data Example by Salesforce Field Type

There is an example file within this repository that has an example fake snowfakery use case for each Salesforce field type: [SeededRecord__c](https://github.com/department-of-veterans-affairs/dtc-release-cicd-local/blob/master/cicd_local/data-faker-station/recipes/SeededRecord__c.RecordType_One.yml)

### Simple Snowfakery value Examples by Field Type

    'checkbox' =             [PSCustomObject]@{ 'recipe'='${{ random_choice("true","false") }}' ; }
    'currency' =             [PSCustomObject]@{ 'recipe'='${{ fake.pyfloat( right_digits = 2, positive=True, min_value=None, max_value=1000000) }}'; }
    'date' =                 [PSCustomObject]@{ 'recipe'='${{ fake.date}}'; } 
    'datetime' =             [PSCustomObject]@{ 'recipe'='${{ fake.date}}'; } 
    'email' =                [PSCustomObject]@{ 'recipe'='${{ fake.ascii_safe_email}}'; }
    'number' =               [PSCustomObject]@{ 'recipe'='${{ fake.pyint( min_value = -10000, max_value = 100000 ) }}'; }
    'percent' =              [PSCustomObject]@{ 'recipe'='${{ fake.pyint( min_value = 0, max_value = 100) }}'; }
    'picklist' =             [PSCustomObject]@{ 'recipe'='${{ random_choice("alpha","bravo","charlie","delta","foxtrot") }}'; }
    'phone' =                [PSCustomObject]@{ 'recipe'='${{ fake.phone_number }}'; }
    'multiselectpicklist' =  [PSCustomObject]@{ 'recipe'='${{ ";".join(( fake.random_sample( elements=("alpha","bravo","charlie","delta","echo","foxtrot" ) ) )) }}'; }
    'text' =                 [PSCustomObject]@{ 'recipe'='${{ fake.text(max_nb_chars=20) }}'; }
    'html' =                 [PSCustomObject]@{ 'recipe'='${{ fake.sentence }}'; }
    'textarea' =             [PSCustomObject]@{ 'recipe'='${{ fake.paragraph }}'; }
    'time' =                 [PSCustomObject]@{ 'recipe'='${{ fake.time }}'; }
    'longtextarea' =         [PSCustomObject]@{ 'recipe'='${{ fake.paragraph }}'; }
    'url' =                  [PSCustomObject]@{ 'recipe'='${{ fake.url }}'; }
    'location' =             [PSCustomObject]@{ 'recipe'='##### SEE ONE PAGER FOR NECESSARY ADJUSTMENTS: https://github.com/jdschleicher/demo-dreamhouse-lwc-shift-left/blob/main/shift_left_toolkit/data-faker-station/documentation/Snowfakery-Recipe-One-Pager.md#:~:text=by%20Field%20Type-,Location%20Field,-A%20location%20type'; }
    'lookup' =               [PSCustomObject]@{ 'recipe'='##### SEE ONE PAGER FOR NECESSARY ADJUSTMENTS: https://github.com/jdschleicher/demo-dreamhouse-lwc-shift-left/blob/main/shift_left_toolkit/data-faker-station/documentation/Snowfakery-Recipe-One-Pager.md#:~:text=fake%3A%20longitude-,Lookup%20Field,-In%20order%20to'; }
    'encryptedtext' =        [PSCustomObject]@{ 'recipe'='${{ fake.credit_card_number }}'; }


        *** FOR WORKING WITH CHARACTER RESTRICTSIONS IN TEXT FIELDS ***
        text : ${{ fake.text(max_nb_chars=18) }}
        
        *** FOR WORKING WITH WHOLE NUMBERS ***
        number_between_range: ${{random_number(min=5, max=10)}}
        any_number: ${{ fake.random_number }}

***

### Complex Snowfakery value Examples by Field Type
***
                    
**Location Field**
```YAML

A location type field will require a latitude and longitude value as it is a:
 "Compound Field" - https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/compound_fields_geolocation.htm. 
To satisfy this compound field syntax within a snowfakery recipe we will provide a latitude and longitude. 
For example, if the field's api name was "geolocation__c"

   geolocation__latitude__s:
     fake: latitude
   geolocation__longitude__s:
     fake: longitude

```

***

**Lookup Field**
```YAML

In order to seamlessly pass a generated snowfakery recipe into an actual insertion to an environment, 
the format we use to populate a lookup field is customized to work with texei's data import. 
The syntax is "ObjectApiName__cRef${{reference(nickname_of_the_object_representing_the_lookup)}}

In the SeededRecord__c example, there is a field "PreviousSeededRecord__c" which is a self-lookup field. 
At the end of the initial SeededRecord__c fields there is a "friends" section in the same YAML indent 
as "fields".  This section represents a "for every generated records of me generate these records in this friends section". 
The friends section for a self-lookup field for SeededRecord__c is as follows:

  - object: SeededRecord__c
  nickname: SeededRecordParent1
  count: 1
  fields:
     ....
  friends:
    - object: SeededRecord__c
      count: 5
      fields:
        PreviousSeededRecord__c: SeededRecord__cRef${{reference(SeededRecordParent1)}}
        ...

The "...." is filler for where other fields would usually be. This recipe will generate 5 child SeededRecords 
for the initial SeededRecord object with the nickname "SeededRecordParent1"
   
```

***

**Dependent Picklist**
```YAML

By referencing an existing picklist option and associated values we can setup our recipe value for a dependent 
picklist like below (parent picklist included in example):

     picklist1__c:
       random_choice:
         - 'bravo'
         - 'alpha'
         - 'charlie'
         - 'delta'
         - 'echo'
         - 'foxtrot'
    dependentpicklist1__c:
      if:
        - choice:
            when: ${{picklist1__c=='alpha'}}
            pick:
              random_choice:
                - sierra
        - choice:
            when: ${{picklist1__c=='bravo'}}
            pick:
              random_choice:
                - sierra
                - tango
        - choice:
            when: ${{picklist1__c=='charlie'}}
            pick:
              random_choice:
                - sierra
                - tango
                - uniform
                - victor
        - choice:
            when: ${{picklist1__c=='delta'}}
            pick:
              random_choice:
                - sierra
                - tango
                - uniform
                - victor
        - choice:
            when: ${{picklist1__c=='echo'}}
            pick:
              random_choice:
                - sierra
                - tango
        - choice:
            when: ${{picklist1__c=='foxtrot'}}
            pick:
              random_choice:
                - sierra
```
