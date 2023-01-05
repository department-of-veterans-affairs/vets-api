## VA Forms

The VA Forms API is a service that synchronises form data from va.gov's 
Drupal CMS system. The CMS system syncs data from the VA source of truth
(Forms DB) nightly between 12AM and 1 AM. The form_reloader.rb SideKiq job then 
syncs the CMS content to our local Postgres DB.
To configure `vets-api` for use with VA Forms, configure
`config/settings.local.yml` with the settings given to you by devops or your
team. For example,

```
# config/settings.local.yml
va_forms:
  drupal_username: 
  drupal_password: 
  drupal_url: 
```

Since the CMS URL is only accessible over SOCKS, ensure that you have SOCKS properly 
configured and running if populating data locally, using form_reloader.rb

To troubleshoot differences between the vets-api version of a form and the 
Drupal CMS version, you may log into the Drupal explorer on socks and run
GraphQL queries against it. Contact the CMS team for a login.

A sample query to find the form 10-10EZ record in Drupal:

```
{
  nodeQuery(
    limit: 1000
    offset: 0
    filter: {
      conditions: [
        { field: "field_va_form_number", value: "10-10ez%", operator: LIKE }
      ]
    }
  ) {
    entities {
      entityId
      entityBundle
      ... on NodeVaForm {
        fieldVaFormNumber
        fieldVaFormName
        fieldVaFormTitle
        fieldVaFormDeleted
        fieldVaFormToolUrl {
          uri
          title
          options
        }
      }
    }
  }
}
```