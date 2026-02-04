# frozen_string_literal: true

module Swagger
  module Requests
    class VeteranStatusCards
      include Swagger::Blocks

      swagger_path '/v0/veteran_status_card' do
        operation :get do
          key :description, 'Retrieve a user Veteran Status Card'
          key :operationId, 'veteranStatusCard'
          key :tags, %w[veteran_status_card]

          parameter :authorization

          response 200 do
            key :description, 'Successful veteran status card retrieval'

            schema do
              key :required, %i[type attributes]
              property :type, type: :string do
                key :enum, %w[veteran_status_card veteran_status_alert]
                key :description, "'veteran_status_card' or 'veteran_status_alert' depending on the vet eligibility"
              end
              property :attributes, type: :object do
                key :required, %i[veteran_status service_summary_code service_history_status]
                key :description, "Displays data specific to either 'confirmed' or 'not confirmed' veteran status card"
                property :full_name, type: :string do
                  key :'x-nullable', true
                  key :description,
                      'The concatenated full name of the veteran, displayed when eligible for a status card'
                  key :example, 'John T Doe Jr'
                end
                property :disability_rating, type: :integer do
                  key :'x-nullable', true
                  key :description, 'The disability rating for the veteran when eligible for a status card'
                  key :example, 50
                end
                property :latest_service, type: :object do
                  key :required, %i[branch begin_date end_date]
                  key :'x-nullable', true
                  key :description,
                      'The latest branch of service, begin date, and end date when the veteran ' \
                      'is eligible for a status card'
                  property :branch, type: :string do
                    key :'x-nullable', true
                    key :description, "The veteran's latest branch of service"
                    key :example, 'Army'
                  end
                  property :begin_date, type: :string, format: :date do
                    key :'x-nullable', true
                    key :description, "The start date of the veteran's latest service"
                    key :example, '2025-01-01'
                  end
                  property :end_date, type: :string, format: :date do
                    key :'x-nullable', true
                    key :description, "The end date of the veteran's latest service"
                    key :example, '2025-12-31'
                  end
                end
                property :edipi, type: :string do
                  key :'x-nullable', true
                  key :description, "The user's EDIPI number when eligible for a veteran status card"
                  key :example, '001001999'
                end
                property :header, type: :string do
                  key :'x-nullable', true
                  key :description, 'Displays an error/warning title when the veteran is ineligible for a status card'
                  key :example, "You're not eligible for a Veteran Status Card"
                end
                property :body, type: :array do
                  key :'x-nullable', true
                  key :description,
                      'A list of message components to display when the veteran is ineligible for a status card'
                  items do
                    key :type, :object
                    key :required, %i[type value]
                    property :type, type: :string do
                      key :enum, %w[text phone link]
                      key :description, "The type of message component - can be 'text', 'phone', or 'link'"
                      key :example, 'text'
                    end
                    property :value, type: :string do
                      key :description, 'The content to be displayed based on the data type'
                      key :example, 'Your record is missing information about your service history or discharge status.'
                    end
                    property :tty, type: :boolean do
                      key :'x-nullable', true
                      key :description, "An optional parameter when data type is 'phone' to signify TTY"
                      key :example, true
                    end
                    property :url, type: :string do
                      key :'x-nullable', true
                      key :description, "When data type is 'link', this field contains the hyperlink"
                      key :example, 'https://www.va.gov'
                    end
                  end
                end
                property :alert_type, type: :string do
                  key :'x-nullable', true
                  key :enum, %w[error warning]
                  key :description, "The type of alert - can either be 'error' or 'warning'"
                  key :example, 'warning'
                end
                property :veteran_status, type: :string do
                  key :enum, ['confirmed', 'not confirmed']
                  key :description,
                      "'confirmed' or 'not confirmed' depending on if the veteran is eligible for a status card"
                  key :example, 'confirmed'
                end
                property :not_confirmed_reason, type: :string do
                  key :'x-nullable', true
                  key :enum, %w[ERROR MORE_RESEARCH_REQUIRED NOT_TITLE_38 PERSON_NOT_FOUND]
                  key :description, 'Displays the reason the veteran is not eligible for a status card'
                  key :example, 'PERSON_NOT_FOUND'
                end
                property :confirmation_status, type: :string do
                  key :'x-nullable', true
                  key :enum,
                      %w[DISCHONORABLE_SSC_CODE INELIGIBLE_SSC_CODE UNKNOWN_SSC_CODE EDIPI_NO_PNL_SSC_CODE
                         CURRENTLY_SERVING_SSC_CODE ERROR_SSC_CODE UNCAUGHT_SSC_CODE UNKNOWN_REASON]
                  key :description, 'Displays the confirmation status of the veteran'
                  key :example, 'INELIGIBLE_SSC_CODE'
                end
                property :service_summary_code, type: :string do
                  key :description, "The veteran's Service Summary Code determined by VAProfile"
                  key :example, 'A5'
                end
                property :service_history_status, type: :string do
                  key :enum, %w[found empty]
                  key :description, "The veteran's service history status - can either be 'found' or 'empty'"
                  key :example, 'found'
                end
              end
            end
          end
        end
      end
    end
  end
end
