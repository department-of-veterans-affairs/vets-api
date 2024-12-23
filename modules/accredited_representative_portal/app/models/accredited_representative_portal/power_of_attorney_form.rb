# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyForm < ApplicationRecord
    belongs_to :power_of_attorney_request,
               class_name: 'AccreditedRepresentativePortal::PowerOfAttorneyRequest',
               inverse_of: :power_of_attorney_form


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

    # Maybe can manage interdepencies between this and the POA reqeust without
    # exposing this.
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
      self.claimant_state_code = address['state_code']
      self.claimant_zip_code = address['zip_code']
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
              "record_disclosure": {
                "type": "boolean",
                "example": true
              },
              "record_disclosure_limitations": {
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
              "address_change": {
                "type": "boolean",
                "example": false
              }
            },
            "required": [
              "record_disclosure",
              "record_disclosure_limitations",
              "address_change"
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
                  "address_line1": {
                    "type": "string",
                    "example": "123 Main St"
                  },
                  "address_line2": {
                    "type": ["string", "null"],
                    "example": "Apt 1"
                  },
                  "city": {
                    "type": "string",
                    "example": "Springfield"
                  },
                  "state_code": {
                    "type": "string",
                    "example": "IL"
                  },
                  "country": {
                    "type": "string",
                    "example": "US"
                  },
                  "zip_code": {
                    "type": "string",
                    "example": "62704"
                  },
                  "zip_code_suffix": {
                    "type": ["string", "null"],
                    "example": "6789"
                  }
                },
                "required": [
                  "address_line1",
                  "address_line2",
                  "city",
                  "state_code",
                  "country",
                  "zip_code",
                  "zip_code_suffix"
                ]
              },
              "date_of_birth": {
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
              "date_of_birth",
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
                  "address_line1": {
                    "type": "string",
                    "example": "123 Main St"
                  },
                  "address_line2": {
                    "type": ["string", "null"],
                    "example": "Apt 1"
                  },
                  "city": {
                    "type": "string",
                    "example": "Springfield"
                  },
                  "state_code": {
                    "type": "string",
                    "example": "IL"
                  },
                  "country": {
                    "type": "string",
                    "example": "US"
                  },
                  "zip_code": {
                    "type": "string",
                    "example": "62704"
                  },
                  "zip_code_suffix": {
                    "type": ["string", "null"],
                    "example": "6789"
                  }
                },
                "required": [
                  "address_line1",
                  "address_line2",
                  "city",
                  "state_code",
                  "country",
                  "zip_code",
                  "zip_code_suffix"
                ]
              },
              "ssn": {
                "type": "string",
                "example": "123456789"
              },
              "va_file_number": {
                "type": ["string", "null"],
                "example": "123456789"
              },
              "date_of_birth": {
                "type": "string",
                "format": "date",
                "example": "1980-12-31"
              },
              "service_number": {
                "type": ["string", "null"],
                "example": "123456789"
              },
              "service_branch": {
                "type": ["string", "null"],
                "enum": [
                  "ARMY",
                  "NAVY",
                  "AIR_FORCE",
                  "MARINE_CORPS",
                  "COAST_GUARD",
                  "SPACE_FORCE",
                  "NOAA",
                  "USPHS"
                ],
                "example": "ARMY"
              },
              "phone": {
                "type": ["string", "null"],
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
              "va_file_number",
              "date_of_birth",
              "service_number",
              "service_branch",
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
