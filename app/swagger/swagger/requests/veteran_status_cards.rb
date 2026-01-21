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
              key :required, [:confirmed]
              property :confirmed, type: :boolean,
                                   description: 'True or False depending on if the veteran is eligible \
                                    for a status card'
              property :full_name, type: :object do
                key :description, 'Displays the veterans name when eligible for a status card'
                property :first, type: :string
                property :middle, type: :string
                property :last, type: :string
                property :suffix, type: :string
              end
              property :user_percent_of_disability, type: :integer,
                                                    description: 'Displays the veterans disability rating \
                                                      when eligible for a status card'
              property :latest_service_history, type: :object do
                key :description, 'Displays the veterans latest service history when eligible for a status card'
                property :branch_of_service, type: :string
                property :latest_service_date_range, type: :object do
                  property :begin_date, type: :string
                  property :end_date, type: :string
                end
              end
              property :title, type: :string,
                               description: 'Displays an error/warning title when the veteran is ineligible \
                                for a status card'
              property :message, type: :string,
                                 description: 'Displays an error/warning message when the veteran is ineligible \
                                  for a status card'
              property :status, type: :string,
                                description: "Displays either 'error' or 'warning' when the veteran is ineligible \
                                  for a status card"
            end
          end
        end
      end
    end
  end
end
