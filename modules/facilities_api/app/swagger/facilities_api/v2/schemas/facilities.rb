# frozen_string_literal: true

module FacilitiesApi
  class V2::Schemas::Facilities
    include Swagger::Blocks

    swagger_schema :Facilities do
      key :required, [:data]
      property :data do
        key :type, :array
        items do
          key :$ref, :Facility
        end
      end
    end

    swagger_schema :Facility do
      property :id, type: :string, example: 'vha_999'
      property :type, type: :string, example: 'va_facilities'

      property :attributes, type: :object do
        property :address, type: %i[object null] do
          key :description, 'Physical and mailing addresses for facilities'
          property :physical do
            key :$ref, :FacilityAddress
          end
          property :mailing do
            key :$ref, :FacilityAddress
          end
        end

        property :classification, type: %i[string null], example: 'VA Medical Center'
        property :facility_type, type: :string, example: 'va_health_facility'

        property :feedback, type: %i[object null] do
          property :health, type: :object do
            key :description, 'Patient satisfaction scores for health facilities'
            property :primaryCareRoutine, type: :number, format: :float, example: 95.2
            property :primaryCareUrgent, type: :number, format: :float, example: 89.1
            property :specialtyCareRoutine, type: :number, format: :float, example: 78
            property :specialtyCareUrgent, type: :number, format: :float, example: 75.3
          end
          property :effectiveDate, type: :string, format: :date, example: '2017-07-01'
        end

        property :hours, type: :object do
          key :description, 'Hours of operation for facilities'
          property :monday, type: :string, example: '800AM-430PM'
          property :tuesday, type: :string, example: '800AM-430PM'
          property :wednesday, type: :string, example: '800AM-430PM'
          property :thursday, type: :string, example: '800AM-430PM'
          property :friday, type: :string, example: '800AM-430PM'
          property :saturday, type: :string, example: 'Closed'
          property :sunday, type: :string, example: 'Closed'
        end

        property :id, type: :string, example: 'vha_999'
        property :lat, type: :number, format: :float, example: -122.5
        property :long, type: :number, format: :float, example: 45.5
        property :mobile, type: %i[boolean null], example: false
        property :name, type: :string, example: 'Example VAMC'

        property :operatingStatus, type: :object do
          key :description, 'Current status of facility operations.'
          property :code, type: :string, example: 'NORMAL'
          property :additionalInfo, type: :string, example: 'Additional information about the operating status.'
        end

        property :operationalHoursSpecialInstructions, type: %i[array null] do
          items type: :string
        end

        property :phone, type: :object do
          key :description, 'Telephone numbers for facilities'
          property :main, type: %i[string null], example: '212-555-1212'
          property :fax, type: %i[string null], example: '212-555-1212'
          property :afterHours, type: %i[string null], example: '212-555-1212'
          property :patientAdvocate, type: %i[string null], example: '212-555-1212'
          property :enrollmentCoordinator, type: %i[string null], example: '212-555-1212'
          property :pharmacy, type: %i[string null], example: '212-555-1212'
          property :mentalHealthClinic, type: %i[string null], example: '212-555-1212 x 123'
        end

        property :services, type: %i[object null] do
          property :other, type: :array do
            items type: :string
          end
          property :health, type: :array do
            property :name, type: %i[string null], example: 'Dermatology'
            property :serviceId, type: %i[string null], example: 'dermatology'
            property :link, type: %i[string null], example: 'http://www.example.com'
          end
          property :link, type: %i[string null], example: 'http://www.example.com'
          property :lastUpdated, type: %i[string null], example: '2017-07-01'
        end

        property :uniqueId, type: :string, example: '999'
        property :visn, type: %i[string null], example: '17'
        property :website, type: %i[string null], example: 'http://www.example.com'
      end
    end

    swagger_schema :FacilityAddress do
      key :type, :object
      property :address1, type: %i[string null], example: '123 Fake Street'
      property :address2, type: %i[string null], example: 'Suite 001'
      property :address3, type: %i[string null]
      property :city, type: %i[string null], example: 'Anytown'
      property :state, type: %i[string null], example: 'NY'
      property :zip, type: %i[string null], example: '00001'
    end

    swagger_schema :Provider do
      property :id, type: :string, example: '40c344a12877bf2dd2828067839d71d0f6affe1e076f267fdaa1aa4927c6da88'
      property :type, type: :string, example: 'provider'

      property :attributes, type: :object do
        property :acc_new_patients, type: :boolean
        property :address, type: :object do
          property :street, type: :string, example: '308 Sherwood Inlet'
          property :city, type: :string, example: 'Cormierton'
          property :state, type: :string, example: 'MT'
          property :zip, type: :string, example: '41390'
        end
        property :caresite_phone, type: :string, example: '6418432280'
        property :email, type: %i[string null]
        property :fax, type: %i[string null]
        property :gender, type: :string, example: 'Female'
        property :lat, type: :number, example: -85.085761
        property :long, type: :number, example: -125.282372
        property :name, type: :string, example: 'Madie Mayert'
        property :phone, type: %i[string null]
        property :pos_codes, type: %i[string null]
        property :pref_contact, type: %i[string null]
        property :unique_id, type: :integer, example: 7_960_178_946
      end
    end

    swagger_schema :Specialty do
      property :id, type: :string, example: '101Y00000X'
      property :type, type: :string, example: 'specialty'

      property :attributes, type: :object do
        property :classification, type: :string, example: 'Counselor'
        property :grouping, type: :string, example: 'Behavioral Health & Social Service Providers'
        property :name, type: :string, example: 'Counselor'
        property :specialization, type: %i[string null], example: 'Clinical'
        property :specialty_code, type: :string, example: '101Y00000X'
        property :specialty_description, type: :string, example: 'Definition to come...'
      end
    end
  end
end
