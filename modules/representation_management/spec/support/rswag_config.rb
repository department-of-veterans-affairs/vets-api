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
          schemas: {
            Errors: {
              type: :object,
              required: [:errors],
              properties: {
                errors: {
                  type: :array,
                  items: { '$ref' => '#/components/schemas/Error' }
                }
              }
            },
            Error: {
              type: :string
            },
            PowerOfAttorneyResponse: {
              type: :object,
              properties: {
                data: {
                  type: :object,
                  properties: {
                    id: {
                      type: :string,
                      example: '123456'
                    },
                    type: {
                      type: :string,
                      description: 'Specifies the category of Power of Attorney (POA) representation.',
                      enum: %w[veteran_service_representatives veteran_service_organizations]
                    },
                    attributes: {
                      type: :object,
                      properties: {
                        type: {
                          type: :string,
                          example: 'organization',
                          description: 'Type of Power of Attorney representation',
                          enum: %w[organization representative]
                        },
                        name: {
                          type: :string,
                          example: 'Veterans Association'
                        },
                        address_line1: {
                          type: :string,
                          example: '1234 Freedom Blvd'
                        },
                        city: {
                          type: :string,
                          example: 'Arlington'
                        },
                        state_code: {
                          type: :string,
                          example: 'VA'
                        },
                        zip_code: {
                          type: :string,
                          example: '22204'
                        },
                        phone: {
                          type: :string,
                          example: '555-1234'
                        },
                        email: {
                          type: :string,
                          example: 'contact@example.org'
                        }
                      },
                      required: %w[type name address_line1 city state_code zip_code]
                    }
                  }
                }
              }
            }
          }
          # Put PowerOfAttorneyResponse here
          # Probably define veteran and claimant params here as well.
        },
        paths: {},
        # basePath is not valid OAS v3
        servers: [
          {
            url: 'http://localhost:3000',
            description: 'Local server',
            variables: {
              version: {
                default: 'v1'
              }
            }
          },

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
