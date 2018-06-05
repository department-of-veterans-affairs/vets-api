# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class DataTranslation
      def initialize(form_content)
        @form_content = form_content
      end

      def convert
        @form_content['form526']['claimantCertification'] = true
        convert_treatments
        @form_content['form526']['applicationExpirationDate'] = application_expiration_date
        @form_content['form526']['veteran']['primaryPhone'] = split_phone_number(@form_content['form526']['veteran']['phone'])
        @form_content['form526']['serviceInformation']['reservesNationalGuardService']['unitPhone'] = split_phone_number(@form_content['form526']['serviceInformation']['reservesNationalGuardService']['unitPhone'])
        convert_service_periods

        veteran_info = @form_content['form526']['veteran']
        @form_content['form526']['veteran']['mailingAddress'] = convert_mailing_address(veteran_info['mailingAddress'])
        if veteran_info['forwardingAddress']
          @form_content['form526']['veteran']['forwardingAddress'] = convert_mailing_address(veteran_info['forwardingAddress'])
        end

        if @form_content['form526']['veteran']['homelessness']
          convert_homelessness
        end

        @form_content.to_json
      end

      private

      def convert_homelessness
        if name = @form_content['form526']['veteran']['homelessness']['pointOfContactName']
          @form_content['form526']['veteran']['homelessness']['haspointOfContact'] = true

          @form_content['form526']['veteran']['homelessness']['pointOfContact'] = {
            'pointOfContactName' => name,
            'primaryPhone' => split_phone_number(@form_content['form526']['veteran']['homelessness']['primaryPhone'])
          }
        end
      end

      def convert_service_periods
        @form_content['form526']['serviceInformation']['servicePeriods'].map! do |sp|
        {
          'serviceBranch' => service_branch(sp['serviceBranch']),
          'activeDutyBeginDate' => sp['dateRange']['from'],
          'activeDutyEndDate' => sp['dateRange']['to']
        }
        end
      end

      def service_branch(service_branch)
        if service_branch == 'NOAA'
          'National Oceanic &amp; Atmospheric Administration'
        else
          service_branch
        end
      end

      def split_phone_number(phone_number)
        area_code, number = phone_number.match(/(\d{3})(\d{7})/).captures
        { 'areaCode' => area_code, 'phoneNumber' => number }
      end

      def rename_date_range(date_range)
        # before: confinementDateRange: { from: '', to: '' }
        # after: confinementBeginDate: '', confinementEndDate: ''
        # see also: obligationTermOfServiceDateRange
        # treatmentDateRange and servicePeriod.dateRange follow this same pattern but I've taken care of them separately. DRY it up as you please
      end

      def convert_mailing_address(address)
        pciu_address = { 'country' => address['country'],
                         'addressLine1' => address['addressLine1'],
                         'addressLine2' => address['addressLine2'],
                         'addressLine3' => address['addressLine3'],
                         'effectiveDate' => address['effectiveDate'] }

        pciu_address['type'] = get_address_type(address)

        case pciu_address['type']
        when 'DOMESTIC'
          zip_code = split_zip_code(address['zipCode'])
          pciu_address['city'] = address['city']
          pciu_address['state'] = address['state']
          pciu_address['zipFirstFive'] = zip_code.first
          pciu_address['zipLastFour'] = zip_code.last
        when 'MILITARY'
          pciu_address['militaryPostOfficeTypeCode'] = address['city']
          pciu_address['militaryStateCode'] = address['state']
        when 'INTERNATIONAL'
          pciu_address['city'] = address['city']
        end

        pciu_address.compact
      end

      def get_address_type(address)
        case address['country']
        when 'USA'
          %w[AA AE AP].include?(address['state']) ? 'MILITARY' : 'DOMESTIC'
        else
          'INTERNATIONAL'
        end
      end

      def split_zip_code(zip_code)
        split_code = zip_code.match(/(^\d{5})(?:([-\s]?)(\d{4})?$)/).captures
      end

      def convert_treatments
        @form_content['form526']['treatments'].map! do |treatment|
          treatment['center'] = {
            'name' => treatment['treatmentCenterName'],
            'type' => treatment['treatmentCenterType'],
          }
          treatment['center'].merge!(treatment['treatmentCenterAddress'])
          treatment['startDate'] = treatment['treatmentDateRange']['from']
          treatment['endDate'] = treatment['treatmentDateRange']['to']
          treatment.delete('treatmentCenterName')
          treatment.delete('treatmentDateRange')
          treatment.delete('treatmentCenterAddress')
          treatment.delete('treatmentCenterType')
          treatment
        end
      end

      def application_expiration_date
        # this is the logic EVSS has given us (RAD stands for Return from Active Duty):
        # IF (the most recent 'RAD date' exists) AND (most recent 'RAD date' > 'application create date') THEN 'Application Expiration Date' = RAD + 1 + 365 ELSEIF ('application create date' < 'ITF date') or (ITF date is null) or (ITF expiration date is null) THEN 'Application Expiration Date' = 'Application Create Date' + 365 ELSE 'Application Expiration Date' = 'ITF Expiration Date'
        # see question 1 here: https://github.com/department-of-veterans-affairs/vets.gov-team/blob/master/Products/Disability%20Compensation/engineering/EVSS/swagger_q%26a.md
      end
    end
  end
end
