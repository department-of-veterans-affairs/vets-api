## Developer Setup

The BPDS forward proxy can be set up locally following the instructions documented here:
https://github.com/department-of-veterans-affairs/va.gov-team/blob/2f04df4b725cae761f7dda1eaa2ca476bab5af49/products/health-care/digital-health-modernization/engineering/mhv-api-tunnel-setup.md

For local setup, replace the bpds.jwt_secret in settings.yml or development.yml with the official dev key in the parameter store. Here is the link to the secret in the parameter store:
https://us-gov-west-1.console.amazonaws-us-gov.com/systems-manager/parameters/%252Fdsva-vagov%252Fvets-api%252Fdev%252Fenv_vars%252Fbpds%252Fjwt_secret/description?region=us-gov-west-1&tab=Table#list_parameter_filters=Name:Contains:%2Fdsva-vagov%2Fvets-api%2Fdev%2Fenv_vars%2Fbpds%2Fjwt_secret

Schema

There was a lot of discussion on the best way to organize form submissions and submission attempts without relying on the FormSubmission and FormSubmissionAttempts tables. We considered defining a new set of base tables for submissions and attempts and using delegated types with a table for each submission and attempt type that recorded attributes specific to each type.

It was concluded that this setup and the table relationships that would need to exist were too complex to maintain for the limited list of submission types that probably won't be growing anytime soon. We opted to create separate tables for each submission/attempt type and create an abstract class for each type to extend when defining type-specific business logic.

Link to the schema diagram: https://lucid.app/lucidchart/21b8ad0b-9d9b-4326-909e-1a0affabb8ea/edit?invitationId=inv_650ed567-5705-4175-9348-d93943d71ca5&page=0_0#



### List of Architectual Decisions

| Summary                                  | Link                                                         | Date       |
| ---------------------------------------- | ------------------------------------------------------------ | ---------- |
| Initial Research and Findings            | [0002-initial-research-and-findings.md](adr/0002-initial-research-and-findings.md) | 2024-12-10 |
| Credentials                              | [0003-received-credentials.md](adr/0003-received-credentials.md) | 2025-01-13 |
| Connected to BDPS                        | [0004-successfully-connected-to-bpds.md](adr/0004-successfully-connected-to-bpds.md) | 2025-02-04 |
| BPDS service class                       | [0005-created-service-class.md](adr/0005-created-service-class.md) | 2025-03-07 |
| Schema Changes                           | [0006-db-schema-changes.md](adr/0006-db-schema-changes.md)   | 2025-04-03 |
| Adding new submission and attempt models | [0007-adding-new-submission-and-attempt-models.md](adr/0007-adding-new-submission-and-attempt-models.md) | 2025-05-01 |
| Sidekiq Job                              | [0008-adding-sidekiq-job.md](adr/0008-adding-sidekiq-job.md) | 2025-05-08 |
|                                          |                                                              |            |

​	
