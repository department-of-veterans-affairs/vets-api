The BPDS forward proxy can be set up locally following the instructions documented here:
 https://github.com/department-of-veterans-affairs/va.gov-team/blob/2f04df4b725cae761f7dda1eaa2ca476bab5af49/products/health-care/digital-health-modernization/engineering/mhv-api-tunnel-setup.md

For local setup, replace the bpds.jwt_secret in settings.yml or development.yml with the official dev key in the parameter store. Here is the link to the secret in the parameter store:
 https://us-gov-west-1.console.amazonaws-us-gov.com/systems-manager/parameters/%252Fdsva-vagov%252Fvets-api%252Fdev%252Fenv_vars%252Fbpds%252Fjwt_secret/description?region=us-gov-west-1&tab=Table#list_parameter_filters=Name:Contains:%2Fdsva-vagov%2Fvets-api%2Fdev%2Fenv_vars%2Fbpds%2Fjwt_secret

We still currently have a gap in our knowledge regarding the function of the MAS system. We will eventually need a way to link the JSON submission to a VA claim ID, since the POI system relies on the claim ID to process submissions. We may eventually generate our own claim IDs for each submission and expose an API endpoint to return a list of unprocessed claim IDs or submissions, but that will be fleshed out when we have more information.

Schema

There was a lot of discussion on the best way to organize form submissions and submission attempts without relying on the FormSubmission and FormSubmissionAttempts tables. We considered defining a new set of base tables for submissions and attempts and using delegated types with a table for each submission and attempt type that recorded attributes specific to each type.

It was concluded that this setup and the table relationships that would need to exist were too complex to maintain for the limited list of submission types that probably won't be growing anytime soon. We opted to create separate tables for each submission/attempt type and create an abstract class for each type to extend when defining type-specific business logic.

Link to the schema diagram: https://lucid.app/lucidchart/21b8ad0b-9d9b-4326-909e-1a0affabb8ea/edit?invitationId=inv_650ed567-5705-4175-9348-d93943d71ca5&page=0_0#