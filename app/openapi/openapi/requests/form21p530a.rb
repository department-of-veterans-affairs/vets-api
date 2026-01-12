# frozen_string_literal: true

module Openapi
  module Requests
    class Form21p530a
      # The exact list the front end uses, addressSchema references the countries constant in vets-json-schema
      COUNTRIES_3 = VetsJsonSchema::CONSTANTS['countries'].collect { |country| country['value'] }

      FORM_SCHEMA = {
        '$schema': 'json-schemer://openapi30/schema',
        type: :object,
        properties: {
          veteranInformation: {
            type: :object,
            required: %i[fullName dateOfBirth dateOfDeath],
            properties: {
              fullName: { '$ref' => '#/components/schemas/FirstMiddleLastName' },
              ssn: {
                type: :string,
                pattern: '^[0-9]{9}$',
                description: 'Social Security Number (9 digits)',
                example: '123456789'
              },
              vaServiceNumber: { type: :string, example: '987654321' }, # does not exist on FE
              vaFileNumber: { type: :string, example: '987654321', pattern: '^\\d{8,9}$' },
              dateOfBirth: { type: :string, format: :date, example: '1980-01-01' },
              dateOfDeath: { type: :string, format: :date, example: '1980-01-01' },
              placeOfBirth: {
                type: :object,
                properties: {
                  city: { type: :string, example: 'Kansas City' },
                  # note, the FE specifies an enum of us states (full name, i.e. "Alabama"),
                  # but we probably want to allow for foreign births
                  state: { type: :string, example: 'MO' }

                }
              }
            }
          },
          veteranServicePeriods: {
            type: :object,
            properties: {
              periods: {
                type: :array,
                items: {
                  type: :object,
                  required: %i[serviceBranch],
                  properties: {
                    serviceBranch: { type: :string, example: 'Army' },
                    # FE dateEnteredService is required if periods exist
                    dateEnteredService: { type: :string, format: :date, example: '1968-06-01' },
                    placeEnteredService: { type: :string, example: 'Fort Benning, GA' },
                    rankAtSeparation: { type: :string, example: 'Sergeant' },
                    # FE dateLeftService is required if periods exist
                    dateLeftService: { type: :string, format: :date, example: '1972-05-31' },
                    placeLeftService: { type: :string, example: 'Fort Hood, TX' }
                  }
                }
              },
              servedUnderDifferentName: {
                type: :string,
                description: 'Name the veteran served under, if different from veteranInformation/fullName',
                example: 'John Smith'
              }
            }
          },
          burialInformation: {
            type: :object,
            required: %i[nameOfStateCemeteryOrTribalOrganization dateOfBurial],
            properties: {
              nameOfStateCemeteryOrTribalOrganization: {
                type: :string,
                description: 'Name of state cemetery or tribal organization claiming interment allowance',
                example: 'Missouri State Veterans Cemetery'
              },
              placeOfBurial: {
                type: :object,
                required: %i[stateCemeteryOrTribalCemeteryName stateCemeteryOrTribalCemeteryLocation],
                properties: {
                  stateCemeteryOrTribalCemeteryName: {
                    type: :string,
                    description: 'State cemetery or tribal cemetery name',
                    example: 'Missouri State Veterans Cemetery'
                  },
                  stateCemeteryOrTribalCemeteryLocation: {
                    type: :string,
                    description: 'State cemetery or tribal cemetery location',
                    example: 'Higginsville, MO' # FE enforces that this is a "City, US State"
                  }
                }
              },
              dateOfBurial: {
                type: :string,
                format: :date,
                example: '2024-01-15'
              },
              recipientOrganization: {
                type: :object,
                required: %w[
                  name
                  phoneNumber
                  address
                ],
                properties: {
                  name: {
                    type: :string,
                    example: 'Missouri Veterans Commission'
                  },
                  phoneNumber: {
                    type: :string,
                    example: '555-123-4567'
                    # FE enforces this pattern, but we likely want to allow international numbers
                    # "pattern": "^\\d{3}-?\\d{3}-?\\d{4}$"
                  },
                  address: {
                    type: :object,

                    properties: {
                      streetAndNumber: {
                        type: :string,
                        minLength: 1,
                        maxLength: 100,
                        example: '2400 Veterans Memorial Drive'
                      },
                      aptOrUnitNumber: {
                        type: :string,
                        maxLength: 5,
                        description: 'Apartment or unit number (max 5 characters)',
                        example: 'Suite'
                      },
                      city: {
                        type: :string,
                        minLength: 1,
                        maxLength: 100,
                        example: 'Higginsville'
                      },
                      state: {
                        type: :string,
                        example: 'MO'
                      },
                      country: {
                        type: :string,
                        maxLength: 3,
                        example: 'USA'
                        # we cannot validate the country in the schema because it is transformed before it is saved as a
                        # SavedClaim, which also validates against the schema
                        # fix in https://github.com/department-of-veterans-affairs/va.gov-team/issues/128935
                        # enum: COUNTRIES_3
                      },
                      postalCode: {
                        type: :string,
                        example: '64037'
                      }
                    }
                  }
                }
              }
            }
          },
          certification: {
            type: :object,
            required: %i[titleOfStateOrTribalOfficial signature certified],
            properties: {
              titleOfStateOrTribalOfficial: {
                type: :string,
                description: 'Title of state or tribal official delegated responsibility to apply for federal funds',
                example: 'Director of Veterans Services'
              },
              signature: {
                type: :string,
                description: 'Signature of state or tribal official',
                example: 'John Doe'
              },
              certified: {
                type: :boolean,
                enum: [true],
                description: 'Certified by the state or tribal official (must be true)',
                example: true
              }
            }
          },
          remarks: { type: :string }
        },
        required: %i[veteranInformation burialInformation certification]
      }.freeze
    end
  end
end
