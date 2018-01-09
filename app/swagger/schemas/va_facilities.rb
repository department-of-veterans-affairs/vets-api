# frozen_string_literal: true

module Swagger
  module Schemas
    class VAFacilities
      include Swagger::Blocks

      swagger_schema :VAFacilities do
        key :required, [:data]

        property :data do
          key :type, :array
          items do
            key :'$ref', :VAFacilityObject
          end
        end
      end

      swagger_schema :VAFacility do
        key :required, [:data]

        property :data do
          key :'$ref', :VAFacilityObject
        end
      end

      swagger_schema :VAFacilityObject do
        key :required, [:id, :type, :attributes]

        property :id, type: :string, example: 'vha_999'
        property :type, type: :string, example: 'va_facilities'

        property :attributes, type: :object do
          property :unique_id, type: :string, example: '999'
          property :name, type: :string, example: 'Example VAMC'
          property :facility_type, type: :string, example: 'va_health_facility'
          property :classification, type: [:string, :null], example: 'VA Medical Center'
          property :website, type: [:string, :null], example: 'http://www.example.com'
          property :lat, type: :number, format: :float, example: -122.5
          property :long, type: :number, format: :float, example: 45.5
          property :address do
            key :'$ref', :FacilityAddresses
          end
          property :phone do
            key :'$ref', :FacilityPhones
          end
          property :hours do
            key :'$ref', :FacilityHours
          end
          property :services do
            key :'$ref', :FacilityServices
          end
          property :feedback do
            key :'$ref', :FacilityFeedback
          end
          property :access do
            key :'$ref', :FacilityAccess
          end
        end
      end

      swagger_schema :FacilityAddresses do
        key :type, :object
        key :description, 'Physical and mailing addresses for facilities'

        property :physical do
          key :'$ref', :FacilityAddress
        end
        property :mailing do
          key :'$ref', :FacilityAddress
        end
      end

      swagger_schema :FacilityAddress do
        key :type, :object

        property :address_1, type: :string, example: '123 Fake Street'
        property :address_2, type: [:string, :null], example: 'Suite 001'
        property :address_3, type: [:string, :null]
        property :city, type: :string, example: 'Anytown'
        property :state, type: :string, example: 'NY'
        property :zip, type: :string, example: '00001'
      end

      swagger_schema :FacilityPhones do
        key :type, :object
        key :description, 'Telephone numbers for facilities'

        property :main, type: :string, example: '212-555-1212'
        property :fax, type: :string, example: '212-555-1212'
        property :after_hours, type: :string, example: '212-555-1212'
        property :patient_advocate, type: :string, example: '212-555-1212'
        property :enrollment_coordinator, type: :string, example: '212-555-1212'
        property :pharmacy, type: :string, example: '212-555-1212'
        property :mental_health_clinic, type: :string, example: '212-555-1212 x 123'
      end

      swagger_schema :FacilityHours do
        key :required, [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
        key :type, :object
        key :description, 'Hours of operation for facilities'

        property :monday, type: :string, example: '9am - 5pm'
        property :tuesday, type: :string, example: '9am - 5pm'
        property :wednesday, type: :string, example: '9am - 5pm'
        property :thursday, type: :string, example: '9am - 5pm'
        property :friday, type: :string, example: '9am - 5pm'
        property :saturday, type: :string, example: 'Closed'
        property :sunday, type: :string, example: 'Closed'
      end

      swagger_schema :FacilityServices do
        key :type, :object

        property :last_updated, type: :string, format: :date, example: '2017-07-01'
        property :health do
          key :'$ref', :HealthFacilityServices
        end
      end

      swagger_schema :HealthFacilityServices do
        key :type, :array
        key :description, 'Available services at health facilities'

        items do
          key :'$ref', :HealthServiceCategory
        end
      end

      swagger_schema :HealthServiceCategory do
        key :type, :object

        property :sl1 do
          key :type, :array
          key :example, ['PrimaryCare']
          items do
            key :type, :string
          end
        end
        property :sl2 do
          key :type, :array
          key :example, []
          items do
            key :type, :string
          end
        end
      end

      swagger_schema :FacilityFeedback do
        key :type, :object

        property :health do
          key :'$ref', :HealthFacilityFeedback
        end
      end

      swagger_schema :HealthFacilityFeedback do
        key :type, :object
        key :description, 'Patient satisfaction scores for health facilities'

        property :primary_care_routine, type: :string, format: :float, example: 95.2
        property :primary_care_urgent, type: :string, format: :float, example: 89.1
        property :specialty_care_routine, type: :string, format: :float, example: 78
        property :specialty_care_urgent, type: :string, format: :float, example: 75.3
        property :effective_date, type: :string, format: :date, example: '2017-07-01'
      end

      swagger_schema :FacilityAccess do
        key :type, :object

        property :health do
          key :'$ref', :HealthFacilityAccess
        end
      end

      swagger_schema :HealthFacilityAccess do
        key :type, :object

        property :primary_care do
          key :'$ref', :HealthAccessMetric
        end
        property :mental_health do
          key :'$ref', :HealthAccessMetric
        end
        property :womens_health do
          key :'$ref', :HealthAccessMetric
        end
        property :audiology do
          key :'$ref', :HealthAccessMetric
        end
        property :cardiology do
          key :'$ref', :HealthAccessMetric
        end
        property :gastroenterology do
          key :'$ref', :HealthAccessMetric
        end
        property :opthalmology do
          key :'$ref', :HealthAccessMetric
        end
        property :optometry do
          key :'$ref', :HealthAccessMetric
        end
        property :urology_clinic do
          key :'$ref', :HealthAccessMetric
        end
        property :effective_date, type: :string, format: :date, example: '2017-07-01'
      end

      swagger_schema :HealthAccessMetric do
        key :type, :object
        key :description, 'Health facility wait times for new and established patients'

        property :new, type: [:number, :null], format: :float, example: 10.5
        property :established, type: [:number, :null], format: :float, example: 5.1
      end
    end
  end
end
