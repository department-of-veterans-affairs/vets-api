# frozen_string_literal: true
module Swagger
  module Requests
    class Post911GiBillStatuses
      include Swagger::Blocks

      swagger_path '/v0/post911_gi_bill_status' do
        operation :get do
          key :description, 'Get the Post 911 GI Bill Status for a Veteran'
          key :operationId, 'getPost911GiBillStatus'
          key :tags, [
            'evss'
          ]

          parameter :authorization

          response 200 do
            key :description, 'Response is OK'
            schema do
              key :'$ref', :Post911GiBillStatus
            end
          end
          response 404 do
            key :description, 'Veteran Gi Bill Status not found in EVSS'
            schema do
              key :'$ref', :Errors
            end
          end
        end
      end

      swagger_schema :Post911GiBillStatus do
        key :required, [:data, :meta]

        property :meta, description: 'The response from the EVSS service to vets-api', type: :object do
          key :'$ref', :Meta
        end
        property :data, type: :object do
          property :id, type: :string
          property :type, type: :string, example: 'evss_gi_bill_status_gi_bill_status_responses'
          property :attributes, type: :object do
            property :first_name, type: :string, example: 'Abraham'
            property :last_name, type: :string, example: 'Lincoln'
            property :name_suffix, type: :string, example: 'Jr'
            property :date_of_birth, type: :string, example: '1955-11-12T06:00:00.000+0000'
            property :va_file_number, type: :string, example:'123456789'
            property :regional_processing_office, type: :string, example: 'Central Office Washington, DC'
            property :eligibility_date, type: :string, example: '2004-10-01T04:00:00.000+0000'
            property :delimiting_date, type: :string, example: '2015-10-01T04:00:00.000+0000'
            property :percentage_benefit, type: :integer, example: 100
            property :original_entitlement, type: :integer, example: nil
            property :used_entitlement, type: :integer, example: 10
            property :remaining_entitlement, type: :integer, example: 12
            property :enrollments do
              key :type, :array
              items do
                key :'$ref', :Enrollment
              end
            end
          end
        end
      end

      swagger_schema :Enrollment do
        key :required, [:begin_date]
        property :begin_date, type: :string, example: '2012-11-01T04:00:00.000+00:00'
        property :end_date, type: :string, example: '2012-12-01T05:00:00.000+00:00'
        property :facility_code, type: :string, example: '12345678'
        property :facility_name, type: :string, example: 'Purdue University'
        property :participant_id, type: :string, example: '11170323'
        property :training_type, type: :string, example: 'UNDER_GRAD'
        property :term_id, type: :string, example: nil
        property :hour_type, type: :string, example: nil
        property :full_time_hours, type: :integer, example: 12
        property :full_time_credit_hour_under_grad, type: :integer, example: nil
        property :vacation_day_count, type: :integer, example: 0
        property :on_campus_hours, type: :number, example: 12
        property :online_hours, type: :number, example: 0
        property :yellow_ribbon_amount, type: :number, example: 0
        property :status, type: :string, example: 'Approved'
        property :amendments do
          key :type, :array
          items do
            key :'$ref', :Amendment
          end
        end
      end

      swagger_schema :Amendment do
        key :required, [:type]
        property :on_campus_hours, type: :number
        property :online_hours, type: :number
        property :yellow_ribbon_amount, type: :number
        property :type, type: :string
        property :change_effective_date, type: :string
      end
    end
  end
end