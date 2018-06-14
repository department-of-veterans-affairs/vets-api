# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class DataTranslation
      def initialize(user, form_content)
        @user = user
        @form_content = form_content
      end

      def convert
        form['claimantCertification'] = true
        form['applicationExpirationDate'] = application_expiration_date
        form['directDeposit'] = get_banking_info

        convert_treatments
        convert_service_info
        convert_veteran

        @form_content.compact.to_json
      end

      private

      def form
        @form_content['form526']
      end

      def service_info
        form['serviceInformation']
      end

      def veteran
        form['veteran']
      end

      def convert_service_info
        convert_service_periods
        convert_confinements if service_info['confinements'].present?
        convert_names if service_info['alternateNames'].present?
        if service_info['reservesNationalGuardService']
          service_info['reservesNationalGuardService'] = convert_national_guard_service(
            service_info['reservesNationalGuardService']
          )
        end
      end

      def convert_veteran
        veteran['primaryPhone'] = split_phone_number(veteran['phone'])
        veteran.delete('phone')

        veteran['mailingAddress'] = convert_mailing_address(veteran['mailingAddress'])
        if veteran['forwardingAddress']
          veteran['forwardingAddress'] = convert_mailing_address(veteran['forwardingAddress'])
        end

        homeless_data = veteran['homelessness']
        if homeless_data['isHomeless']
          veteran['homelessness'] = convert_homelessness(homeless_data['pointOfContact'])
        else
          veteran.delete('homelessness')
        end
      end

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

      def convert_service_periods
        service_info['servicePeriods'].map! do |si|
          {
            'serviceBranch' => service_branch(si['serviceBranch']),
            'activeDutyBeginDate' => si['dateRange']['from'],
            'activeDutyEndDate' => si['dateRange']['to']
          }
        end
      end

      def convert_confinements
        service_info['confinements'].map! do |ci|
          {
            'confinementBeginDate' => ci['confinementDateRange']['from'],
            'confinementEndDate' => ci['confinementDateRange']['to'],
            'verifiedIndicator' => ci['verifiedIndicator']
          }
        end
      end

      def convert_names
        service_info['alternateNames'].map! do |an|
          {
            'firstName' => an['first'],
            'middleName' => an['middle'],
            'lastName' => an['last']
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
        }.compact
      end

      def service_branch(service_branch)
        case service_branch
        when 'NOAA'
          'National Oceanic &amp; Atmospheric Administration'
        else service_branch
        end
      end

      def split_phone_number(phone_number)
        area_code, number = phone_number.match(/(\d{3})(\d{7})/).captures
        { 'areaCode' => area_code, 'phoneNumber' => number }
      end

      def get_banking_info
        service = EVSS::PPIU::Service.new(@user)
        response = service.get_payment_information
        account = response.responses.first.payment_account

        if account
          {
            'accountType' => account&.account_type&.upcase,
            'accountNumber' => account&.account_number,
            'routingNumber' => account&.financial_institution_routing_number,
            'bankName' => account&.financial_institution_name
          }
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
        zip_code.match(/(^\d{5})(?:([-\s]?)(\d{4})?$)/).captures
      end

      def convert_treatments
        form['treatments'].map! do |treatment|
          treatment['center'] = {
            'name' => treatment['treatmentCenterName'],
            'type' => treatment['treatmentCenterType']
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
        if rad_date.present? && rad_date > application_create_date
          (rad_date + 1.day + 365.days).iso8601 # expires year after the following day service ends
        elsif itf.creation_date.nil? || itf.expiration_date.nil? || itf.creation_date > application_create_date
          (application_create_date + 365.days).iso8601
        else
          itf.expiration_date.iso8601
        end
      end

      def application_create_date
        # Application create date is the date the user began their application
        @acd ||= InProgressForm.where(form_id: VA526ez::FORM_ID, user_uuid: @user.uuid)
                               .first.created_at
      end

      def rad_date
        # retrieve the most recent 'Return from Active Duty' Date
        @rd ||= Time.zone.parse(@user.military_information.service_episodes_by_date.first&.end_date.to_s)
      end

      def itf
        # retrieve the active intent to file for compensation
        return @itf if @itf

        service = EVSS::IntentToFile::Service.new(@user)
        response = service.get_active('compensation')
        @itf = response.intent_to_file
      end
    end
  end
end
