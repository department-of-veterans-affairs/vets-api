# frozen_string_literal: true

class RepresentationManagement::RswagConfig
  def config # rubocop:disable Metrics/MethodLength
    {
      'modules/representation_management/app/swagger/v0/swagger.json' => {
        openapi: '3.0.1',
        info: {
          title: 'va.gov Representation Management API',
          version: '1.0.0',
          termsOfService: 'https://developer.va.gov/terms-of-service',
          description: 'The API for managing representation for VA Forms 21-22 and 21-22a'
        },
        tags: [
          {
            name: 'PDF Generation',
            description: 'Generate a PDF form from user input'
          },
          {
            name: 'Power of Attorney',
            description: 'Retrieves the Power of Attorney for a veteran, if any.'
          }
        ],
        components: {
          # Put PowerOfAttorneyResponse here
          # Probably define veteran and claimant params here as well.
        },
        paths: {},
        # basePath is not valid OAS v3
        servers: [
          {
            url: 'https://sandbox-api.va.gov',
            description: 'VA.gov API sandbox environment',
            variables: {
              version: {
                default: 'v1'
              }
            }
          },
          {
            url: 'https://api.va.gov',
            description: 'VA.gov API production environment',
            variables: {
              version: {
                default: 'v1'
              }
            }
          }
        ]
      }
    }
  end
end
