# frozen_string_literal: true
module Swagger
  module Schemas
    class VAFacilities
      include Swagger::Blocks

      swagger_schema :VAFacilities do
        key :required, [:data]

        property :data, type: :array
        items do
          key :'$ref', :VAFacilityObject
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

        property :id, type: :string
        property :type, type: :string

        property :attributes, type: :object do
          property :unique_id, type: :string
          property :name, type: :string
          property :facility_type, type: :string
          property :classification, type: :string
          property :website, type: :string
          property :lat, type: :float
          property :long, type: :float
          property :address do
            key :'$ref', :FacilityAddresses
          end
          property :phone do
            key :'$ref', :FacilityPhones
          end
          property :hours do
            key :'$ref', :FacilityHours
          end
          property :feedback do
            key :'$ref', :FacilityFeedback
          end
        end
      end

      swagger_schema :FacilityAddresses do
        key :type, :object

        property :physical do
          key :'$ref', :FacilityAddress
        end
        property :mailing do
          key :'$ref', :FacilityAddress
        end
      end

      swagger_schema :FacilityAddress do
        key :type, :object

        property :address_1, type: :String
        property :address_2, type: :String
        property :address_3, type: :String
        property :city, type: :String
        property :state, type: :String
        property :zip, type: :String
      end

      swagger_schema :FacilityPhones do
        key :type, :object

        property :main, type: :string
        property :fax, type: :string
        property :after_hours, type: :string
        property :patient_advocate, type: :string
        property :enrollment_coordinator, type: :string
        property :pharmacy, type: :string
        property :mental_health_clinic, type: :string
      end

      swagger_schema :FacilityHours do
        key :required, [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
        key :type, :object
       
        property :monday, type: :string
        property :tuesday, type: :string
        property :wednesday, type: :string
        property :thursday, type: :string
        property :friday, type: :string
        property :saturday, type: :string
        property :sunday, type: :string
      end
    
      swagger_schema :FacilityFeedback do
        key :type, :object

        property :health do
          key :'$ref', :HealthFacilityFeedback 
        end
      end

      swagger_schema :HealthFacilityFeedback do
        key :type, :object

        property :primary_care_routine, type: :string, format: :float
        property :primary_care_urgent, type: :string, format: :float
        property :specialty_care_routine, type: :string, format: :float
        property :specialty_care_urgent, type: :string, format: :float
        property :effective_date, type: :string, format: :date
      end
    end
  end
end

# "unique_id":"648",
# "name":"Portland VA Medical Center",
# "facility_type":"va_health_facility",
# "classification":"VA Medical Center (VAMC)",
# "website":"http://www.portland.va.gov/",
# "lat":45.49746145,
# "long":-122.68287208,
# "address":{
#  "physical":{"address_1":"3710 Southwest US Veterans Hospital Road",
#              "address_2":null,
#              "address_3":null,
#              "city":"Portland",
#              "state":"OR",
#              "zip":"97239-2964"},
#  "mailing":{}},
# "phone":{"main":"503-721-1498 x",
#   "fax":"503-273-5319 x",
#   "after_hours":"503-220-8262 x",
#   "patient_advocate":"503-273-5308 x",
#   "enrollment_coordinator":"503-273-5069 x",
#   "pharmacy":"503-273-5183 x",
#   "mental_health_clinic":"503-273-5187"},
# "hours":{"monday":"24/7",
#          "tuesday":"24/7",
#          "wednesday":"24/7",
#          "thursday":"24/7",
#          "friday":"24/7",
#          "saturday":"24/7",
#          "sunday":"24/7"},
# "services":{
#   "last_updated":"2017-06-09",
#   "health":[{"sl1":["DentalServices"],"sl2":[]},
#             {"sl1":["MentalHealthCare"],"sl2":[]},
#             {"sl1":["PrimaryCare"],"sl2":[]}]
#  },
#  "feedback":{
#   "health":{"primary_care_urgent":"0.72",
#             "primary_care_routine":"0.82",
#             "specialty_care_routine":"0.79",
#             "specialty_care_urgent":"0.69",
#             "effective_date":"2017-03-24"}
#  },
#  "access":{
#   "health":{"primary_care":{"new":49.0,"established":10.0},
#             "mental_health":{"new":19.0,"established":1.0},
#             "womens_health":{"new":null,"established":1.0},
#             "audiology":{"new":27.0,"established":10.0},
#             "cardiology":{"new":28.0,"established":13.0},
#             "gastroenterology":{"new":22.0,"established":12.0},
#             "opthalmology":{"new":20.0,"established":8.0},
#             "optometry":{"new":45.0,"established":20.0},
#             "urology_clinic":{"new":20.0,"established":5.0},
#             "effective_date":"2017-07-17"}
