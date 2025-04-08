# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyForm < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'PowerOfAttorneyRequest',
               inverse_of: :power_of_attorney_form

    ##
    # If we had a regular ID column, we could use `eager_encrypt` which would be
    # more performant:
    # https://github.com/ankane/kms_encrypted/blob/master/README.md?plain=1#L155
    #
    has_kms_key

    has_encrypted(
      :data,
      :claimant_city,
      :claimant_state_code,
      :claimant_zip_code,
      key: :kms_key,
      **lockbox_options
    )

    blind_index(
      :claimant_city,
      :claimant_state_code,
      :claimant_zip_code
    )

    validate :data_must_comply_with_schema
    before_validation :set_location

    ##
    # Maybe can manage interdepencies between this and the POA reqeust without
    # exposing this.
    #
    def parsed_data
      @parsed_data ||= JSON.parse(data)
    end

    private

    def set_location
      claimant = parsed_data['dependent']
      claimant ||= parsed_data['veteran']

      address = claimant.to_h['address']
      return unless address

      self.claimant_city = address['city']
      self.claimant_state_code = address['stateCode']
      self.claimant_zip_code = address['zipCode']
    end

    def data_must_comply_with_schema
      data_errors = JSONSchemer.schema(SCHEMA).validate(parsed_data)
      return if data_errors.none?

      errors.add :data, 'does not comply with schema'
    end

    ##
    # TODO: Can couple this to the schema involved in user input during POA
    # request creation.
    #
    # Currently, it is a small-ish transformation of the most closely related
    # schema in existence at the time of writing:
    #   [The schema for 2122 PDF generation](https://github.com/department-of-veterans-affairs/vets-api/blob/124adcfbeb4cba0d17f69e392d2af6189acd4809/modules/representation_management/app/swagger/v0/swagger.json#L749-L948)
    #
    # Of note:
    # - Optional `dependent` property for the non-Veteran claimant (NVC) case
    #   - Does NVC necessarily mean a claimant that is a dependent of the Veteran?
    #   - If so, using the name `dependent` lets us use the word `claimant` more straightforwardly
    #     - `poa_request.claimant_type` is `{ veteran | dependent }`
    # - All properties required but some nullable
    #   - Rather than representing optionality by omission from `required` properties
    #
    SCHEMA = <<~JSON
      {
        "type": "object",
        "properties": {
          "authorizations": {
            "type": "object",
            "properties": {
              "recordDisclosure": {
                "type": "boolean",
                "example": true
              },
              "recordDisclosureLimitations": {
                "type": "array",
                "items": {
                  "type": "string",
                  "enum": [
                    "ALCOHOLISM",
                    "DRUG_ABUSE",
                    "HIV",
                    "SICKLE_CELL"
                  ]
                },
                "example": [
                  "ALCOHOLISM",
                  "DRUG_ABUSE",
                  "HIV",
                  "SICKLE_CELL"
                ]
              },
              "addressChange": {
                "type": "boolean",
                "example": false
              }
            },
            "required": [
              "recordDisclosure",
              "recordDisclosureLimitations",
              "addressChange"
            ]
          },
          "dependent": {
            "type": ["object", "null"],
            "properties": {
              "name": {
                "type": "object",
                "properties": {
                  "first": {
                    "type": "string",
                    "example": "John"
                  },
                  "middle": {
                    "type": ["string", "null"],
                    "example": "Middle"
                  },
                  "last": {
                    "type": "string",
                    "example": "Doe"
                  }
                },
                "required": [
                  "first",
                  "middle",
                  "last"
                ]
              },
              "address": {
                "type": "object",
                "properties": {
                  "addressLine1": {
                    "type": "string",
                    "example": "123 Main St"
                  },
                  "addressLine2": {
                    "type": ["string", "null"],
                    "example": "Apt 1"
                  },
                  "city": {
                    "type": "string",
                    "example": "Springfield"
                  },
                  "stateCode": {
                    "type": "string",
                    "example": "IL"
                  },
                  "country": {
                    "type": "string",
                    "example": "US"
                  },
                  "zipCode": {
                    "type": "string",
                    "example": "62704"
                  },
                  "zipCodeSuffix": {
                    "type": ["string", "null"],
                    "example": "6789"
                  }
                },
                "required": [
                  "addressLine1",
                  "addressLine2",
                  "city",
                  "stateCode",
                  "country",
                  "zipCode",
                  "zipCodeSuffix"
                ]
              },
              "dateOfBirth": {
                "type": "string",
                "format": "date",
                "example": "1980-12-31"
              },
              "relationship": {
                "type": "string",
                "example": "Spouse"
              },
              "phone": {
                "type": ["string", "null"],
                "pattern": "^\\\\d{10}$",
                "example": "1234567890"
              },
              "email": {
                "type": ["string", "null"],
                "example": "dependent@example.com"
              }
            },
            "required": [
              "name",
              "address",
              "dateOfBirth",
              "relationship",
              "phone",
              "email"
            ]
          },
          "veteran": {
            "type": "object",
            "properties": {
              "name": {
                "type": "object",
                "properties": {
                  "first": {
                    "type": "string",
                    "example": "john"
                  },
                  "middle": {
                    "type": ["string", "null"],
                    "example": "middle"
                  },
                  "last": {
                    "type": "string",
                    "example": "doe"
                  }
                },
                "required": [
                  "first",
                  "middle",
                  "last"
                ]
              },
              "address": {
                "type": "object",
                "properties": {
                  "addressLine1": {
                    "type": "string",
                    "example": "123 Main St"
                  },
                  "addressLine2": {
                    "type": ["string", "null"],
                    "example": "Apt 1"
                  },
                  "city": {
                    "type": "string",
                    "example": "Springfield"
                  },
                  "stateCode": {
                    "type": "string",
                    "example": "IL"
                  },
                  "country": {
                    "type": "string",
                    "example": "US"
                  },
                  "zipCode": {
                    "type": "string",
                    "example": "62704"
                  },
                  "zipCodeSuffix": {
                    "type": ["string", "null"],
                    "example": "6789"
                  }
                },
                "required": [
                  "addressLine1",
                  "addressLine2",
                  "city",
                  "stateCode",
                  "country",
                  "zipCode",
                  "zipCodeSuffix"
                ]
              },
              "ssn": {
                "type": "string",
                "example": "123456789"
              },
              "vaFileNumber": {
                "type": ["string", "null"],
                "example": "123456789"
              },
              "dateOfBirth": {
                "type": "string",
                "format": "date",
                "example": "1980-12-31"
              },
              "serviceNumber": {
                "type": ["string", "null"],
                "example": "123456789"
              },
              "serviceBranch": {
                "type": ["string", "null"],
                "enum": [
                  "ARMY",
                  "NAVY",
                  "AIR_FORCE",
                  "MARINE_CORPS",
                  "COAST_GUARD",
                  "SPACE_FORCE",
                  "NOAA",
                  "USPHS",
                  null
                ],
                "example": "ARMY"
              },
              "phone": {
                "type": ["string", "null"],
                "pattern": "^\\\\d{10}$",
                "example": "1234567890"
              },
              "email": {
                "type": ["string", "null"],
                "example": "veteran@example.com"
              }
            },
            "required": [
              "name",
              "address",
              "ssn",
              "vaFileNumber",
              "dateOfBirth",
              "serviceNumber",
              "serviceBranch",
              "phone",
              "email"
            ]
          }
        },
        "required": [
          "authorizations",
          "veteran",
          "dependent"
        ]
      }
    JSON
  end
end
