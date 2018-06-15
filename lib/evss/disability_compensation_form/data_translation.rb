# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class DataTranslation
      def initialize(user, form_content)
        @user = user
        @form_content = form_content
      end

      def translate
        form['claimantCertification'] = true
        form['applicationExpirationDate'] = application_expiration_date
        form['directDeposit'] = get_banking_info

        translate_service_info
        translate_veteran
        translate_treatments

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

      def translate_service_info
        translate_service_periods
        translate_confinements if service_info['confinements'].present?
        translate_names if service_info['alternateNames'].present?
        if service_info['reservesNationalGuardService'].present?
          service_info['reservesNationalGuardService'] = translate_national_guard_service(
            service_info['reservesNationalGuardService']
          )
        end
      end

      def translate_service_periods
        service_info['servicePeriods'].map! do |si|
          {
            'serviceBranch' => service_branch(si['serviceBranch']),
            'activeDutyBeginDate' => si['dateRange']['from'],
            'activeDutyEndDate' => si['dateRange']['to']
          }
        end
      end

      def translate_confinements
        service_info['confinements'].map! do |ci|
          {
            'confinementBeginDate' => ci['confinementDateRange']['from'],
            'confinementEndDate' => ci['confinementDateRange']['to'],
            'verifiedIndicator' => ci['verifiedIndicator']
          }
        end
      end

      def translate_names
        service_info['alternateNames'].map! do |an|
          {
            'firstName' => an['first'],
            'middleName' => an['middle'],
            'lastName' => an['last']
          }.compact
        end
      end

      def translate_national_guard_service(reserves_service_info)
        {
          'title10Activation' => reserves_service_info['title10Activation'],
          'obligationTermOfServiceFromDate' => reserves_service_info['obligationTermOfServiceDateRange']['from'],
          'obligationTermOfServiceToDate' => reserves_service_info['obligationTermOfServiceDateRange']['to'],
          'unitName' => reserves_service_info['unitName'],
          'unitPhone' => split_phone_number(reserves_service_info['unitPhone']),
          'inactiveDutyTrainingPay' => reserves_service_info['inactiveDutyTrainingPay']
        }.compact
      end

      def translate_veteran
        translate_veteran_phone
        translate_veteran_address
        translate_homelessness
      end

      def translate_veteran_phone
        veteran['primaryPhone'] = split_phone_number(veteran['phone'])
        veteran.delete('phone')
      end

      def translate_veteran_address
        veteran['mailingAddress'] = translate_mailing_address(veteran['mailingAddress'])
        if veteran['forwardingAddress'].present?
          veteran['forwardingAddress'] = translate_mailing_address(veteran['forwardingAddress'])
        end
      end

      def translate_homelessness
        data = veteran['homelessness']
        return veteran.delete('homelessness') if data['isHomeless'].blank?
        return veteran['homelessness'] = { 'hasPointOfContact' => false } if data['pointOfContact'].blank?
        veteran['homelessness'] = {
          'hasPointOfContact' => true,
          'pointOfContact' => {
            'pointOfContactName' => data.dig('pointOfContact', 'pointOfContactName'),
            'primaryPhone' => split_phone_number(data.dig('pointOfContact', 'primaryPhone'))
          }
        }
      end

      def service_branch(service_branch)
        return 'National Oceanic &amp; Atmospheric Administration' if service_branch == 'NOAA'
        service_branch
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

      def translate_mailing_address(address)
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
        return 'MILITARY' if %w[AA AE AP].include?(address['state'])
        return 'DOMESTIC' if address['country'] == 'USA'
        'INTERNATIONAL'
      end

      def split_zip_code(zip_code)
        zip_code.match(/(^\d{5})(?:([-\s]?)(\d{4})?$)/).captures
      end

      def translate_treatments
        form['treatments'].map! do |treatment|
          treatment['center'] = {
            'name' => treatment['treatmentCenterName'],
            'type' => treatment['treatmentCenterType']
          }
          treatment['center'].merge!(treatment['treatmentCenterAddress'])
          treatment['startDate'] = treatment['treatmentDateRange']['from']
          treatment['endDate'] = treatment['treatmentDateRange']['to']
          treatment.except('treatmentCenterName', 'treatmentDateRange', 'treatmentCenterAddress', 'treatmentCenterType')
        end
      end

      def application_expiration_date
        return (rad_date + 1.day + 365.days).iso8601 if greater_rad_date?
        return (application_create_date + 365.days).iso8601 if greater_itf_date?
        itf.expiration_date.iso8601
      end

      def greater_rad_date?
        rad_date.present? && rad_date > application_create_date
      end

      def greater_itf_date?
        itf.creation_date.nil? || itf.expiration_date.nil? || itf.creation_date > application_create_date
      end

      def application_create_date
        # Application create date is the date the user began their application
        @acd ||= InProgressForm.where(form_id: VA526ez::FORM_ID, user_uuid: @user.uuid)
                               .first.created_at
      end

      def rad_date
        # retrieve the most recent 'Return from Active Duty' Date
        return @rd if @rd

        service_episodes = @user.military_information.service_episodes_by_date
        @rd = Time.zone.parse(service_episodes.first&.end_date.to_s)
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
