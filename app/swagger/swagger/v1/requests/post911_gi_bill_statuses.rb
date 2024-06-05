# frozen_string_literal: true

class Swagger::V1::Requests::Post911GIBillStatuses
  include Swagger::Blocks

  swagger_path '/v1/post911_gi_bill_status' do
    operation :get do
      extend Swagger::Responses::AuthenticationError

      key :description, 'Get the Post 911 GI Bill Status for a Veteran'
      key :operationId, 'getPost911GiBillStatus'
      key :tags, ['benefits_status']

      parameter :authorization

      response 200 do
        key :description, 'Response is OK'
        schema do
          key :$ref, :Post911GiBillStatus
        end
      end

      response 404 do
        key :description, 'Veteran Gi Bill Status not found in Lighthouse'
        schema do
          key :$ref, :Errors
        end
      end

      response 503 do
        key :description, 'The backend GI Bill Status service is unavailable'
        header 'Retry-After' do
          key :type, :string
          key :format, 'date'
        end
        schema do
          key :$ref, :Errors
        end
      end
    end
  end

  swagger_schema :Post911GiBillStatus do
    key :required, %i[data]

    property :data, description: 'The response from the Lighthouse service to vets-api', type: :object do
      property :id, type: :string
      property :type, type: :string, example: 'lighthouse_gi_bill_status_gi_bill_status_responses'
      property :attributes, type: :object do
        property :first_name, type: :string, example: 'Abraham'
        property :last_name, type: :string, example: 'Lincoln'
        property :name_suffix, type: %i[string null], example: 'Jr'
        property :date_of_birth, type: %i[string null], example: '1955-11-12T06:00:00.000+0000'
        property :va_file_number, type: %i[string null], example: '123456789'
        property :regional_processing_office, type: %i[string null], example: 'Central Office Washington, DC'
        property :eligibility_date, type: %i[string null], example: '2004-10-01T04:00:00.000+0000'
        property :delimiting_date, type: %i[string null], example: '2015-10-01T04:00:00.000+0000'
        property :percentage_benefit, type: %i[integer null], example: 100
        property :veteran_is_eligible, type: %i[boolean null], example: false
        property :active_duty, type: %i[boolean null], example: false
        property :original_entitlement, type: :object do
          key :$ref, :Entitlement
        end
        property :used_entitlement, type: :object do
          key :$ref, :Entitlement
        end
        property :remaining_entitlement, type: :object do
          key :$ref, :Entitlement
        end
        property :enrollments do
          key :type, :array
          items do
            key :$ref, :Enrollment
          end
        end
      end
    end
  end

  swagger_schema :Enrollment do
    key :required, [:begin_date]
    property :begin_date, type: :string, example: '2012-11-01T04:00:00.000+00:00'
    property :end_date, type: %i[string null], example: '2012-12-01T05:00:00.000+00:00'
    property :facility_code, type: %i[string null], example: '12345678'
    property :facility_name, type: %i[string null], example: 'Purdue University'
    property :participant_id, type: %i[integer null], example: 1234
    property :training_type, type: %i[string null], example: 'UNDER_GRAD'
    property :term_id, type: %i[string null], example: nil
    property :hour_type, type: %i[string null], example: nil
    property :full_time_hours, type: %i[integer null], example: 12
    property :full_time_credit_hour_under_grad, type: %i[integer null], example: nil
    property :vacation_day_count, type: %i[integer null], example: 0
    property :on_campus_hours, type: %i[number null], format: :float, example: 12.0
    property :online_hours, type: %i[number null], format: :float, example: 0.0
    property :yellow_ribbon_amount, type: %i[number null], format: :float, example: 0.0
    property :status, type: %i[string null], example: 'Approved'
    property :amendments do
      key :type, :array
      items do
        key :$ref, :Amendment
      end
    end
  end

  swagger_schema :Amendment do
    key :required, [:type]
    property :on_campus_hours, type: %i[number null], format: :float, example: 10.5
    property :online_hours, type: %i[number null], format: :float, example: 3.5
    property :yellow_ribbon_amount, type: %i[number null], format: :float, example: 5.25
    property :type, type: %i[string null]
    property :change_effective_date, type: %i[string null], example: '2012-12-01T05:00:00.000+00:00'
  end

  swagger_schema :Entitlement do
    key :required, %i[days months]
    property :days, type: :integer
    property :months, type: :integer
  end
end
