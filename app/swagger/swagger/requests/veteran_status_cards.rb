# frozen_string_literal: true

module Swagger
  module Requests
    class VeteranStatusCards
      include Swagger::Blocks

      swagger_path '/v0/veteran_status_cards' do
        operation :get do
          key :description, 'Retrieve a user Veteran Status Card'
          key :operationId, 'veteranStatusCard'
          key :tags, %w[veteran_status_card]

          parameter :authorization

          response 200 do
            key :description, 'Successful veteran status card retrieval'

            schema do
              property :confirmed, type: :boolean
              property :full_name, type: :object do
                property :first, type: :string
                property :middle, type: :string
                property :last, type: :string
                property :suffix, type: :string
              end
              property :user_percent_of_disability, type: :integer
              property :latest_service_history, type: :object do
                property :branch_of_service, type: :string
                property :latest_service_date_range, type: :object do
                  property :begin_date, type: :string
                  property :end_date, type: :string
                end
              end
              property :title, type: :string, description: 'When the user is ineligible for a vet status card, this field is populated'
              property :message, type: :string, description: 'When the user is ineligible for a vet status card, this field is populated'
              property :status, type: :string, description: 'When the user is ineligible for a vet status card, this field is populated'
            end
          end
        end
      end
    end
  end
end
