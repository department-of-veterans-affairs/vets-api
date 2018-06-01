# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class DataTranslation
      def initialize(form_content)
        @form_content = form_content
        binding.pry
      end

      def convert

      end

      private

      #add type to address, if military add city and state to military properties
      def address_type(country, state_code)
        if country == "USA"
          if ["AA", "AE", "AP"].include?(state_code)
            "MILITARY"
          else
            "DOMESTIC"
          end
        else
          "INTERNATIONAL"
        end
      end

      def convert_service_branch(service_branch)
        if service_branch == 'NOAA'
          'National Oceanic &amp; Atmospheric Administration'
        else
          service_branch
        end
      end

      def split_zip_code(zip_code)
        #Swagger lists this as zipFirstFive and zipLastFour. Our regex for the combined field is '^\d{5}(?:([-\s]?)\d{4})?$'  so it should be pretty easy to split - either on the separator or just 'first five digits' and 'last four digits'
      end

      def split_phone_number(phone_number)
        #Swagger lists this as two separate fields - areaCode with 3 digits and phoneNumber with 7. We have this as a single 10-digit field.
      end

      def rename_date_range(date_range)
        #Swagger lists this in separate fields as activeDutyBeginDate andactiveDutyEndDate. We've renamed it to 'from' and 'to',  and nested it within a dateRange object 
        #see also: obligationTermOfServiceDateRange, confinementDateRange, treatmentDateRange
      end

      def claimantCertification
        true
      end

      def convert_mailing_address(mailing_address)
        #the front end will use the regular address schema (i.e., no wonky type fields), and will send this regular-address data to vets-api, where type info and property conversions will take place so that the data can be submitted to EVSS
      end
      
      def convert_treatments(treatments_array)

      end
    end
  end
end
