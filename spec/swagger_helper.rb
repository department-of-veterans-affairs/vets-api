# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('modules', 'claims_api', 'app', 'swagger', 'claims_api').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1',
        description: <<~VERBIAGE
          This API automatically establishes and submits these VA forms.
          | Form number       | Form name     | Description     |
          | :------------- | :----------: | -----------: |
          | [21-526EZ](https://www.va.gov/find-forms/about-form-21-526ez/) | Application for Disability Compensation and Related Compensation Benefits | Used to apply for VA disability compensation and related benefits. |
          | [21-0966](https://www.va.gov/find-forms/about-form-21-0966/) | Intent to File a Claim for Compensation and/or Pension, or Survivors Pension and/or DIC | Submits an intent to file to secure the earliest possible effective date for any retroactive payments. |
          | [21-22](https://www.va.gov/find-forms/about-form-21-22/) | Appointment of Veterans Service Organization as Claimant's Representative | Used to assign an individual or VSO as a POA to help a Veteran with benefits or claims. |
          | [21-22a](https://www.va.gov/find-forms/about-form-21-22a/) | Appointment of Individual As Claimant's Representative | |

          It also lets Veterans or their authorized representatives:
           - Digitally submit supporting documentation for disability compensation claims
           - Retrieve information such as status for any claim, including pension and burial
           - Retrieve power of attorney (POA) status for individuals and Veterans Service Organizations (VSOs)
           - Retrieve intent to file status

          ## Background
          The Benefits Claims API offers faster establishment and enhanced reporting for several VA claims and forms. Using this API provides many benefits, such as:
           - Automatic claim and POA establishment
           - Direct establishment of disability compensation claims in Veterans Benefits Management System (VBMS) to avoid unnecessary manual processing and entry by Veteran Service Representatives (VSRs)
           - Faster claims processing by several days
           - End-to-end claims status and result tracking by claim ID

          Forms not supported by the Benefits Claims API are submitted using the [Benefits Intake API](https://developer.va.gov/explore/benefits/docs/benefits?version=current), which places uploaded PDFs into the Centralized Mail Portal to be manually processed.

          ## Technical Overview
          This API accepts a payload of requests and responses on a per-form basis, with the payload identifying the form and Veteran. Trackable responses provide a unique ID which is used with the appropriate GET endpoint to track a submission’s processing status.

          ### Attachment and file size limits
          There is no limit on the number of files a payload can contain, but size limits do apply.
           - Uploaded documents cannot be larger than 11" x 11"
           - The entire payload cannot exceed 5 GB
           - No single file in a payload can exceed 100 MB

          ### Authentication and authorization
          To make an API request, follow our [authentication process](https://developer.va.gov/explore/authorization?api=claims) to receive an [OAuth token](https://oauth.net/2/).

          #### Representative authorization
          Representatives seeking authorization for a Veteran must first [authenticate](https://developer.va.gov/explore/authorization?api=claims) and then pass the Veteran’s information in the right header:
           - SSN in X-VA-SSN
           - First name in X-VA-First-Name
           - Last name in X-VA-Last-Name
           - Date of birth in X-VA-Birth-Date

          Omitting the information will cause the API to treat the representative as the claimant.

          #### Veteran authorization
          Veterans seeking authorization do not need to include headers such as X-VA-First-Name since the token authentication via ID.me, MyHealtheVet, or DSLogon provides this information.

          ### POA Codes
          Veteran representatives receive their organization’s POA code. If they are the assigned POA for a Veteran, that Veteran will have a matching POA code. When a claim is submitted, this API verifies that the representative and Veteran codes match against each other and the codes in the [Office of General Council (OGC) Database](https://www.va.gov/ogc/apps/accreditation/index.asp).

          Use the [Power of Attorney endpoint](#operations-Power_of_Attorney-post2122) to assign or update POA status. A newly appointed representative may not be able to submit forms for a Veteran until a day after their POA code is first associated with the OGC data set.

          ### Test data for sandbox environment use
          [Test data](https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts.md) is used for all forms in the sandbox environment and for 21-526 submissions in the staging environment.

          ### Claim and form processing
          Claims and forms are first submitted by this API and then established in VBMS. A 200 response means only that your claim or form was submitted successfully. To see if your submission is processed or has reached VBMS, you must check its status using the appropriate GET endpoint and the ID returned with your submission response.

          A “claim established” status means the claim has reached VBMS. In sandbox, submissions can take over an hour to reach “claim established” status. In production, this may take over two days.
        VERBIAGE
      },
      tags: [
        {
          name: 'Claims',
          description: <<~VERBIAGE
            Allows authenticated and authorized users to access claims data for a single claim by ID, or for all claims based on Veteran data. No data is returned if the user is not authenticated and authorized.
          VERBIAGE
        },
        {
          name: 'Disability',
          description: 'Used for 526 claims.'
        },
        {
          name: 'Intent to File',
          description: 'Used for 0966 submissions.'
        },
        {
          name: 'Power of Attorney',
          description: 'Used for 21-22 and 21-22a form submissions.'
        }
      ],
      components: {
        securitySchemes: {
          bearer_token: {
            type: :http,
            scheme: :bearer
          },
          productionOauth: {
            type: :oauth2,
            description: 'This API uses OAuth 2 with the authorization code grant flow. [More info](https://developer.va.gov/explore/authorization?api=claims)',
            flows: {
              authorizationCode: {
                authorizationUrl: 'https://api.va.gov/oauth2/authorization',
                tokenUrl: 'https://api.va.gov/oauth2/token',
                scopes: {
                  'claim.read': 'Retrieve claim data',
                  'claim.write': 'Submit claim data'
                }
              }
            }
          },
          sandboxOauth: {
            type: :oauth2,
            description: 'This API uses OAuth 2 with the authorization code grant flow. [More info](https://developer.va.gov/explore/authorization?api=claims)',
            flows: {
              authorizationCode: {
                authorizationUrl: 'https://sandbox-api.va.gov/oauth2/authorization',
                tokenUrl: 'https://sandbox-api.va.gov/oauth2/token',
                scopes: {
                  'claim.read': 'Retrieve claim data',
                  'claim.write': 'Submit claim data'
                }
              }
            }
          }
        }
      },
      paths: {},
      basePath: '/services/claims/v1',
      servers: [
        {
          url: 'https://sandbox-api.va.gov/services/claims/{version}',
          description: 'VA.gov API sandbox environment',
          variables: {
            version: {
              default: 'v1'
            }
          }
        },
        {
          url: 'https://api.va.gov/services/claims/{version}',
          description: 'VA.gov API production environment',
          variables: {
            version: {
              default: 'v1'
            }
          }
        }
      ]
    },
    'v2/swagger.json' => {
      openapi: '3.0.1',
      info: {
        title: 'API V2',
        version: 'v2',
        description: <<~VERBIAGE
          This API automatically establishes and submits these VA forms.
          | Form number       | Form name     | Description     |
          | :------------- | :----------: | -----------: |
          | [21-526EZ](https://www.va.gov/find-forms/about-form-21-526ez/) | Application for Disability Compensation and Related Compensation Benefits | Used to apply for VA disability compensation and related benefits. |
          | [21-0966](https://www.va.gov/find-forms/about-form-21-0966/) | Intent to File a Claim for Compensation and/or Pension, or Survivors Pension and/or DIC | Submits an intent to file to secure the earliest possible effective date for any retroactive payments. |
          | [21-22](https://www.va.gov/find-forms/about-form-21-22/) | Appointment of Veterans Service Organization as Claimant's Representative | Used to assign an individual or VSO as a POA to help a Veteran with benefits or claims. |
          | [21-22a](https://www.va.gov/find-forms/about-form-21-22a/) | Appointment of Individual As Claimant's Representative | |

          It also lets Veterans or their authorized representatives:
           - Digitally submit supporting documentation for disability compensation claims
           - Retrieve information such as status for any claim, including pension and burial
           - Retrieve power of attorney (POA) status for individuals and Veterans Service Organizations (VSOs)
           - Retrieve intent to file status

          ## Background
          The Benefits Claims API offers faster establishment and enhanced reporting for several VA claims and forms. Using this API provides many benefits, such as:
           - Automatic claim and POA establishment
           - Direct establishment of disability compensation claims in Veterans Benefits Management System (VBMS) to avoid unnecessary manual processing and entry by Veteran Service Representatives (VSRs)
           - Faster claims processing by several days
           - End-to-end claims status and result tracking by claim ID

          Forms not supported by the Benefits Claims API are submitted using the [Benefits Intake API](https://developer.va.gov/explore/benefits/docs/benefits?version=current), which places uploaded PDFs into the Centralized Mail Portal to be manually processed.

          ## Technical Overview
          This API accepts a payload of requests and responses on a per-form basis, with the payload identifying the form and Veteran. Trackable responses provide a unique ID which is used with the appropriate GET endpoint to track a submission’s processing status.

          ### Attachment and file size limits
          There is no limit on the number of files a payload can contain, but size limits do apply.
           - Uploaded documents cannot be larger than 11" x 11"
           - The entire payload cannot exceed 5 GB
           - No single file in a payload can exceed 100 MB

          ### Authentication and authorization
          To make an API request, follow our [authentication process](https://developer.va.gov/explore/authorization?api=claims) to receive an [OAuth token](https://oauth.net/2/).

          #### Representative authorization
          Accredited representatives may make requests to the Claims API on behalf of Veterans that they represent. To make API requests on behalf of a Veteran, representatives must:
           - be [accredited with the VA Office of the General Counsel](https://www.va.gov/ogc/apps/accreditation/index.asp)
           - be [authenticated](https://developer.va.gov/explore/authorization?api=claims) using an identity-proofed account
           - be the current Power of Attorney (POA) on record for the Veteran (accredited representatives can use the ‘/veterans/{veteranId}/power-of-attorney’ endpoint to check a Veteran’s current POA)

          #### Finding a Veteran's unique VA ID
          The Claims API uses a unique Veteran identifier to identify the subject of each API request. This Veteran identifier can be retrieved by an authenticated Veteran or an accredited representative by passing name, DOB, and SSN to the ‘/veteran-id’ endpoint. This identifier should then be used as the Veteran ID parameter in request URLs.

          *Note: though Veteran identifiers are typically static, they may change over time. If a specific Veteran ID suddenly responds with a ‘404 not found’ error, the identifier may have changed. It’s a good idea to retrieve the current identifier for each Veteran periodically.*

          ### POA Codes
          Veteran representatives receive their organization’s POA code. If they are the assigned POA for a Veteran, that Veteran will have a matching POA code. When a claim is submitted, this API verifies that the representative and Veteran codes match against each other and the codes in the [Office of General Council (OGC) Database](https://www.va.gov/ogc/apps/accreditation/index.asp).

          Use the [Power of Attorney endpoint](#operations-Power_of_Attorney-post2122) to assign or update POA status. A newly appointed representative may not be able to submit forms for a Veteran until a day after their POA code is first associated with the OGC data set.

          ### Test data for sandbox environment use
          [Test data](https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts.md) is used for all forms in the sandbox environment and for 21-526 submissions in the staging environment.

          ### Claim and form processing
          Claims and forms are first submitted by this API and then established in VBMS. A 200 response means only that your claim or form was submitted successfully. To see if your submission is processed or has reached VBMS, you must check its status using the appropriate GET endpoint and the ID returned with your submission response.

          A “claim established” status means the claim has reached VBMS. In sandbox, submissions can take over an hour to reach “claim established” status. In production, this may take over two days.
        VERBIAGE
      },
      tags: [
        {
          name: 'Veteran Identifier',
          description: "Allows authenticated veterans and veteran representatives to retrieve a veteran's id."
        },
        {
          name: 'Claims',
          description: <<~VERBIAGE
            Allows authenticated and authorized users to access claims data for a given Veteran. No data is returned if the user is not authenticated and authorized.
          VERBIAGE
        },
        {
          name: 'Power of Attorney',
          description: 'Used for 21-22 and 21-22a form submissions.'
        }
      ],
      components: {
        securitySchemes: {
          bearer_token: {
            type: :http,
            name: :token,
            scheme: :bearer,
            bearer_format: :JWT
          }
        }
      },
      paths: {},
      basePath: '/services/benefits/v2',
      servers: [
        {
          url: 'https://dev-api.va.gov/services/benefits/{version}',
          description: 'VA.gov API development environment',
          variables: {
            version: {
              default: 'v2'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :json
end
