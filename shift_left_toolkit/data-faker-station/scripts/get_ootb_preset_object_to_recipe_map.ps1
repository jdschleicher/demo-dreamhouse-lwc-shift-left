
$ootb_object_to_recipe_map = @{

    "User"     = get_user_here_string_recipe;
    "Contact"  = get_contact_here_string_recipe;
    "Account"  = get_account_here_string_recipe;

}

function get_user_here_string_recipe {
    $user_here_string = @"
- object: User
nickname: User_NickName
count: 5
fields:
"@

    $user_here_string
}

function get_contact_here_string_recipe {
    $contact_here_string = @"
- object: Contact
nickname: Contact_NickName
count: 5
fields:
    FirstName: `${{ fake: first_name }}
    LastName: `${{ fake: last_name }}
"@

    $contact_here_string
}

function get_account_here_string_recipe {
    $account_here_string = @"
- object: Account
  nickname: Account_NickName
  count: 1
  fields:
    name: `${{ fake: first_name }}
"@

    $account_here_string
}