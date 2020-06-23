# frozen_string_literal: true

module Swagger
  module Schemas
    module Appeals
      class HigherLevelReviewRequest
        include Swagger::Blocks

        swagger_schema :HigherLevelReviewRequest, type: :object do
          key :required, %i[data]
          property :data, type: :object do
            key :required, %i[
              type
              attributes
              relationships
            ]
            property :type, type: :string, enum: %w[HigherLevelReview]
            property :attributes, type: :object do
              key :required, %i[
                receipt_date
                informal_conference
                same_office
                legacy_opt_in_approved
                benefit_type
                veteran
              ]
              property :receipt_date, type: :string, format: :date
              property :informal_conference, type: :boolean do
                key :description, 'Corresponds to "14. ...REQUEST AN INFORMAL CONFERENCE..." on form 20-0996.'
              end
              property :informal_conference_times, type: :array do
                key :description, '"OPTIONAL. Time slot preference for informal conference (if being requested).'\
                                  'EASTERN TIME. Pick up to two time slots (or none if no preference). Corresponds'\
                                  ' to "14. ...REQUEST AN INFORMAL CONFERENCE..." on form 20-0996."'
                items type: :string, enum: %w[800-1000 1000-1230 1230-200 200-430]
              end
              property :informal_conference_rep, type: :object do
                key :description, 'OPTIONAL. The veteran\'s preferred representative for informal conference '\
                                  '(if being requested). Corresponds to "14. ...REQUEST AN INFORMAL '\
                                  'CONFERENCE..." on form 20-0996.'
                property :name, type: :string, description: 'Representative\'s name'
                property :phone_number, type: :string do
                  key :pattern, '^[0-9]+$'
                  key :description, 'Representative\'s phone number. Example: "8446982311". Format: Include'\
                                    ' only digit characters. Include area code.'
                end
                property :phone_number_ext, type: :string do
                  key :description, 'Representative\'s phone number extension (if needed). Example: "123".'
                end
              end
              property :same_office, type: :boolean
              property :legacy_opt_in_approved, type: :boolean
              property :benefit_type, type: :string do
                key :enum, %w[
                  compensation
                  pension
                  fiduciary
                  insurance
                  education
                  voc_rehab
                  loan_guaranty
                  vha
                  nca
                ]
              end
              property :veteran, type: :object do
                key :description, 'The veteran whom this Higher-Level Review concerns. Use the field '\
                                  'fileNumberOrSsn to identify the veteran. Optionally, you can '\
                                  'update the veteran\'s current contact info using the other fields.'\
                                  ' If any of these fields are present: [addressLine1, addressLine2, '\
                                  'city, stateProvinceCode, zipPostalCode, countryCode], all of these'\
                                  'fields must be present: [addressLine1, addressLine2, city, '\
                                  'stateProvinceCode, zipPostalCode]. NOTE: countryCode can be left '\
                                  'out, and it will be assumed to be "US".'
                key :required, %i[file_number_or_ssn]
                property :file_number_or_ssn, type: :string do
                  key :pattern, '^[0-9]{8,9}$'
                  key :description, 'The veteran\'s file number or SSN. Example: "123456789" Format: '\
                                    '8 or 9 digit characters. Max length: 9 characters. Corresponds '\
                                    'to both "1. VETERAN\'S SOCIAL SECURITY NUMBER" '\
                                    'and "2. VA FILE NUMBER" on form 20-0996.'
                end
                property :address_line_1, type: :string do
                  key :description, 'Update a veteran\'s house number/name and street. Example: '\
                                    '"123 Main St". Max length: 100 characters. Corresponds to '\
                                    '"9. CURRENT MAILING ADDRESS: No. & Street" on form 20-0996.'
                end
                property :address_line_2, type: :string do
                  key :description, 'Update a veteran\'s apartment or unit number. Example: '\
                                    '"Apt. 4". Max length: 100 characters. Corresponds to  "9. '\
                                    'CURRENT MAILING ADDRESS: Apt./Unit Number" on form 20-0996.'
                end
                property :city, type: :string do
                  key :description, 'Update a veteran\'s city. Example: "Kansas City". '\
                                    'Max length: 100 characters. Corresponds to '\
                                    '"9. CURRENT MAILING ADDRESS: City" on form 20-0996.'
                end
                property :state_province_code, type: :string do
                  key :pattern, '^[a-z]{2}$'
                end
                property :country_code, type: :string do
                  key :pattern, '^[a-z]{2}$'
                  key :description, 'Update a veteran\'s country. Example: "US". NOTE: If'\
                                    ' not specified, will assume "US". Max length:'\
                                    ' 2 characters. Corresponds to "9. CURRENT MAILING'\
                                    ' ADDRESS: Country" on form 20-0996.'
                end
                property :zip_postal_code, type: :string do
                  key :description, 'Update a veteran\'s zip or postal code. Example:'\
                                    ' "90210". NOTE: If countryCode is "US" or not specified,'\
                                    ' this field, if present, must be a 5 character string '\
                                    'of digits. Corresponds to "9. CURRENT MAILING ADDRESS:'\
                                    ' Zip Code/Postal Code" on form 20-0996.'
                end
                property :phone_number, type: :string do
                  key :pattern, '^[0-9]+$'
                end
                property :phone_number_country_code, type: :string do
                  key :pattern, '^[0-9]+$'
                  key :description, 'Update a veteran\'s phone number country code.'\
                                    ' Note: If not specified, will assume "1".'\
                                    ' Example: "20". Format: Include only digit characters.'
                end
                property :phone_number_ext, type: :string do
                  key :description, 'Update a veteran\'s phone number extension (if '\
                                    'needed). Example: "123". Max length: 10 characters.'
                end
                property :email_address, type: :string do
                  key :pattern, '^.+@.+\..+$'
                  key :description, 'Update a veteran\'s email address. Example: '\
                                    '"linda@example.com". Max length: 255 characters.'\
                                    ' Corresponds to "11. E-MAIL ADDRESS" on form 20-0996.'
                end
              end
              property :claimaint, type: :object do
                key :required, %i[participant_id payee_code]
                property :participant_id, type: :string
                property :payee_code do
                  key :'$ref', :PayeeCode
                end
              end
            end
          end
          property :included, type: :array do
            key :description, 'ContestableIssues Array'
            items type: :object do
              key :description, 'Use the `/contestable_issues` endpoint to pull a list '\
                                'of a veteran\'s contestable issues to select from,'\
                                ' and include the _ContestableIssue_ objects that you '\
                                'want to contest in this array. When including a '\
                                '_ContestableIssue_ obtained from the `/contestable_issues`'\
                                ' endpoint, use the `notes` field to provide '\
                                'additional information about contesting this issue.'\
                                ' **Additionally**, a `legacyAppealIssues` array can be'\
                                ' added to a _ContestableIssue_ object to associate a '\
                                '_LegacyAppealIssue_ to a _ContestableIssue_. '\
                                'Associating a _LegacyAppealIssue_ to a _ContestableIssue_ '\
                                'pulls the _LegacyAppealIssue_ out of the legacy'\
                                ' appeal system and into AMA. See the `legacyAppealIssues`'\
                                ' array below for more info on opting-in legacy '\
                                'issues. _Note:_ Not all legacy issues are eligible for opt-in; see '\
                                '[benefits.va.gov/benefits/docs/apppeals_SOC-SSOC_Opt-in.pdf]'\
                                '(https://www.benefits.va.gov/benefits/docs/apppeals_SOC-SSOC_Opt-in.pdf)'\
                                ' for details.'
              key :required, %i[type attributes]
              property :type, type: :object do
                key :enum, %w[ContestableIssues]
              end
              property :attributes, type: :object do
                property :notes, type: :string
                property :decision_issue_id, type: :integer
                property :rating_issue_id, type: :string
                property :rating_decision_issue_id, type: :string
                property :legacy_appeal_issues, type: :array do
                  key :description, 'LegacyAppealIssues Array'
                  items do
                    key :type, :object
                    key :description, 'OPTIONAL. _LegacyAppealIssues_ that you are associating'\
                                      ' with this _ContestableIssue_. At this time,'\
                                      ' 0 or 1 _LegacyAppealIssues_ can be associated with a'\
                                      ' _ContestableIssue_. A _LegacyAppealIssue_  '\
                                      'can only be associated once in a Higher-Level Review.'\
                                      ' To associate _LegacyAppealIssues_, '\
                                      '`legacyOptInApproved` must be `true`.'
                    key :required, %i[legacy_appeal_id legacy_appeal_issue_id]
                    property :legacy_appeal_id, type: :string
                    property :legacy_appeal_issue_id, type: :string
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
