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
              key :required, %i[type veteran_status attributes]
              property :type, type: :string do
                key :enum, %w[veteran_status_card veteran_status_alert]
                key :description, "'veteran_status_card' or 'veteran_status_alert' depending on the vet eligibility"
              end
              property :veteran_status, type: :string do
                key :enum, ['confirmed', 'not confirmed']
                key :description,
                    "'confirmed' or 'not confirmed' depending on if the veteran is eligible for a status card"
              end
              property :service_summary_code, type: :string do
                key :description, "The veteran's Service Summary Code determined by VAProfile"
              end
              property :not_confirmed_reason, type: :string do
                key :description, 'Displays the reason the veteran is not eligible for a status card'
              end
              property :attributes, type: :object do
                key :description, "Displays data specific to either 'confirmed' or 'not confirmed' veteran status card"
                property :full_name, type: :string do
                  key :description,
                      'The concatenated full name of the veteran, displayed when eligible for a status card'
                end
                property :disability_rating, type: :integer do
                  key :description, 'The disability rating for the veteran when eligible for a status card'
                end
                property :latest_service, type: :object do
                  key :required, %i[branch begin_date end_date]
                  key :description,
                      'The latest branch of service, begin date, and end date when the veteran ' \
                      'is eligible for a status card'
                  property :branch, type: :string, description: "The veteran's latest branch of service"
                  property :begin_date, type: :string, description: "The start date of the veteran's latest service"
                  property :end_date, type: :string, description: "The end date of the veteran's latest service"
                end
                property :edipi, type: :string do
                  key :description, "The user's EDIPI number when eligible for a veteran status card"
                end
                property :header, type: :string do
                  key :description, 'Displays an error/warning title when the veteran is ineligible for a status card'
                end
                property :body, type: :array do
                  key :description,
                      'A list of message components to display when the veteran is ineligible for a status card'
                  items do
                    key :required, %i[type value]
                    property :type, type: :string do
                      key :enum, %w[text phone link]
                      key :description, "The type of message component - can be 'text', 'phone', or 'link'"
                    end
                    property :value, type: :string do
                      key :description, 'The content to be displayed based on the data type'
                    end
                    property :tty, type: :boolean do
                      key :description, "An optional parameter when data type is 'phone' to signify TTY"
                    end
                    property :url, type: :string do
                      key :description, "When data type is 'link', this field contains the hyperlink"
                    end
                  end
                end
                property :alert_type, type: :string do
                  key :description, "The type of alert - can either be 'error' or 'warning'"
                end
              end
            end
          end
        end
      end
    end
  end
end
