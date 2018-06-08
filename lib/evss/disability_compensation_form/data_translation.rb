# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class DataTranslation
      def initialize(user, form_content)
        @user = user
        @form_content = form_content
      end

      def convert
        @form_content['form526']['claimantCertification'] = true

        @form_content['form526']['applicationExpirationDate'] = application_expiration_date

        @form_content['form526']['treatments'] = convert_treatments(@form_content['form526']['treatments'])

        @form_content['form526']['directDeposit'] = get_banking_info(@user)

        service_info = @form_content['form526']['serviceInformation']
        @form_content['form526']['serviceInformation']['servicePeriods'] = convert_service_periods(service_info['servicePeriods'])
        @form_content['form526']['serviceInformation']['confinements'] = convert_confinements(service_info['confinements'])
        if service_info['reservesNationalGuardService']
          @form_content['form526']['serviceInformation']['reservesNationalGuardService'] = convert_national_guard_service(service_info['reservesNationalGuardService'])
        end

        veteran_info = @form_content['form526']['veteran']
        @form_content['form526']['veteran']['primaryPhone'] = split_phone_number(veteran_info['phone'])
        @form_content['form526']['veteran']['mailingAddress'] = convert_mailing_address(veteran_info['mailingAddress'])
        if veteran_info['forwardingAddress']
          @form_content['form526']['veteran']['forwardingAddress'] = convert_mailing_address(veteran_info['forwardingAddress'])
        end

        homeless_data = @form_content['form526']['veteran']['homelessness']
        if homeless_data['isHomeless']
          @form_content['form526']['veteran']['homelessness'] = convert_homelessness(homeless_data['pointOfContact'])
        else
          @form_content['form526']['veteran'].delete('homelessness')
        end

        @form_content.compact.to_json
      end

      private

      def convert_homelessness(point_of_contact)
        homelessness = {}
        if point_of_contact
          homelessness['hasPointOfContact'] = true
          homelessness['pointOfContact'] = {
            'pointOfContactName' => point_of_contact['pointOfContactName'],
            'primaryPhone' => split_phone_number(point_of_contact['primaryPhone'])
          }
        else
          homelessness['hasPointOfContact'] = false
        end

        homelessness
      end

      def convert_service_periods(service_periods_info)
        service_periods_info.map! do |si|
          {
            'serviceBranch' => service_branch(si['serviceBranch']),
            'activeDutyBeginDate' => si['dateRange']['from'],
            'activeDutyEndDate' => si['dateRange']['to']
          }
        end
      end

      def convert_confinements(confinements_info)
        confinements_info.map! do |ci|
          {
            'confinementBeginDate' => ci['confinementDateRange']['from'],
            'confinementEndDate' => ci['confinementDateRange']['to'],
            'verifiedIndicator' => ci['verifiedIndicator']
          }
        end
      end

      def convert_national_guard_service(reserves_service_info)
        {
          'title10Activation' => reserves_service_info['title10Activation'],
          'obligationTermOfServiceFromDate' => reserves_service_info['obligationTermOfServiceDateRange']['from'],
          'obligationTermOfServiceToDate' => reserves_service_info['obligationTermOfServiceDateRange']['to'],
          'unitName' => reserves_service_info['unitName'],
          'unitPhone' => split_phone_number(reserves_service_info['unitPhone']),
          'inactiveDutyTrainingPay' => reserves_service_info['inactiveDutyTrainingPay']
        }
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

      def get_banking_info(user)
        service = EVSS::PPIU::Service.new(user)
        response = service.get_payment_information
        account = response.responses.first.payment_account

        if account
          {
            'accountType' => account&.account_type&.upcase,
            'accountNumber' => account&.account_number,
            'routingNumber' => account&.financial_institution_routing_number,
            'bankName' => account&.financial_institution_name
          }
        else
          nil
        end
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

      def convert_treatments(treatments_info)
        treatments_info.map! do |treatment|
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
