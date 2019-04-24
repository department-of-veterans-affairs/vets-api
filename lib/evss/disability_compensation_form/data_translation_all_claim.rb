# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    # Transforms a client submission into the format expected by the EVSS 526 service
    #
    # @param user [User] The current user
    # @param format [Hash] Hash of the parsed JSON submitted by the client
    # @param has_form4142 [Boolean] Does the submission include a 4142 form
    #
    class DataTranslationAllClaim # rubocop:disable Metrics/ClassLength
      HOMELESS_SITUATION_TYPE = {
        'shelter' => 'LIVING_IN_A_HOMELESS_SHELTER',
        'notShelter' => 'NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT',
        'anotherPerson' => 'STAYING_WITH_ANOTHER_PERSON',
        'fleeing' => 'FLEEING_CURRENT_RESIDENCE',
        'other' => 'OTHER'
      }.freeze

      HOMELESS_RISK_SITUATION_TYPE = {
        'losingHousing' => 'HOUSING_WILL_BE_LOST_IN_30_DAYS',
        'leavingShelter' => 'LEAVING_PUBLICLY_FUNDED_SYSTEM_OF_CARE',
        'other' => 'OTHER'
      }.freeze

      TERMILL_OVERFLOW_TEXT =  "Corporate Flash Details\n" \
                               "This applicant has indicated that they're terminally ill.\n"
      FORM4142_OVERFLOW_TEXT = 'VA Form 21-4142/4142a has been completed by the applicant and sent to the ' \
                               'PMR contractor for processing in accordance with M21-1 III.iii.1.D.2.'

      def initialize(user, form_content, has_form4142)
        @user = user
        @form_content = form_content
        @has_form4142 = has_form4142
        @translated_form = { 'form526' => {} }
      end

      # Performs the translation by merging system user data and data fetched from upstream services
      #
      # @return [Hash] The translated form ready for submission
      #
      def translate
        output_form['claimantCertification'] = true
        output_form['standardClaim'] = input_form['standardClaim']
        output_form['applicationExpirationDate'] = application_expiration_date
        output_form['overflowText'] = overflow_text
        output_form.compact!

        output_form.update(translate_banking_info)
        output_form.update(translate_service_pay)
        output_form.update(translate_service_info)
        output_form.update(translate_veteran)
        output_form.update(translate_treatments)
        output_form.update(translate_disabilities)

        @translated_form
      end

      private

      def input_form
        @form_content['form526']
      end

      def service_info
        input_form['serviceInformation']
      end

      def output_form
        @translated_form['form526']
      end

      def overflow_text
        return nil unless @has_form4142 || input_form['isTerminallyIll'].present?

        overflow = ''
        overflow += TERMILL_OVERFLOW_TEXT if input_form['isTerminallyIll'].present?
        overflow += FORM4142_OVERFLOW_TEXT if @has_form4142

        overflow
      end

      def translate_banking_info
        populated = input_form['bankName'].present? && input_form['bankAccountType'].present? &&
                    input_form['bankAccountNumber'].present? && input_form['bankRoutingNumber'].present?
        # if banking data is not included then it has not changed and will be retrieved
        # from the PPIU service
        if !populated
          get_banking_info
        else
          direct_deposit(
            input_form['bankAccountType'], input_form['bankAccountNumber'],
            input_form['bankRoutingNumber'], input_form['bankName']
          )
        end
      end

      def get_banking_info
        service = EVSS::PPIU::Service.new(@user)
        response = service.get_payment_information
        account = response.responses.first.payment_account

        if can_set_direct_deposit?(account)
          direct_deposit(
            account.account_type, account.account_number,
            account.financial_institution_routing_number, account.financial_institution_name
          )
        else
          {}
        end
      end

      # Direct Deposit cannot be set unless all these fields are set
      def can_set_direct_deposit?(account)
        return unless account
        return if account.account_type.blank?
        return if account.account_number.blank?
        return if account.financial_institution_routing_number.blank?
        return if account.financial_institution_name.blank?
        true
      end

      def direct_deposit(type, account_number, routing_number, bank_name)
        {
          'directDeposit' => {
            'accountType' => type.upcase,
            'accountNumber' => account_number,
            'routingNumber' => routing_number,
            'bankName' => bank_name
          }
        }
      end

      def translate_service_pay
        service_pay = {
          'waiveVABenefitsToRetainTrainingPay' => input_form['waiveTrainingPay'],
          'waiveVABenefitsToRetainRetiredPay' => input_form['waiveRetirementPay'],
          'militaryRetiredPay' => military_retired_pay,
          'separationPay' => separation_pay
        }.compact

        service_pay.present? ? { 'servicePay' => service_pay } : {}
      end

      def military_retired_pay
        return nil if input_form['militaryRetiredPayBranch'].blank?
        {
          'receiving' => true,
          'payment' => {
            'serviceBranch' => service_branch(input_form['militaryRetiredPayBranch'])
          }
        }
      end

      def separation_pay
        return nil if input_form['hasSeparationPay'].blank?

        {
          'received' => true,
          'payment' => payment(input_form['separationPayBranch']),
          'receivedDate' => approximate_date(input_form['separationPayDate'])
        }.compact
      end

      def payment(branch)
        return nil if branch.blank?

        {
          'serviceBranch' => service_branch(branch)
        }
      end

      def translate_service_info
        {
          'serviceInformation' => {
            'servicePeriods' => translate_service_periods,
            'confinements' => translate_confinements,
            'reservesNationalGuardService' => translate_national_guard_service,
            'servedInCombatZone' => input_form['servedInCombatZonePost911'],
            'alternateNames' => translate_names
          }.compact
        }
      end

      def translate_service_periods
        service_info['servicePeriods'].map do |si|
          {
            'serviceBranch' => service_branch(si['serviceBranch']),
            'activeDutyBeginDate' => si['dateRange']['from'],
            'activeDutyEndDate' => si['dateRange']['to']
          }
        end
      end

      def translate_confinements
        return nil if input_form['confinements'].blank?
        input_form['confinements'].map do |ci|
          {
            'confinementBeginDate' => ci['from'],
            'confinementEndDate' => ci['to']
          }
        end
      end

      def translate_national_guard_service
        return nil if service_info['reservesNationalGuardService'].blank?
        reserves_service_info = service_info['reservesNationalGuardService']
        {
          'title10Activation' => reserves_service_info['title10Activation'],
          'obligationTermOfServiceFromDate' => reserves_service_info['obligationTermOfServiceDateRange']['from'],
          'obligationTermOfServiceToDate' => reserves_service_info['obligationTermOfServiceDateRange']['to'],
          'unitName' => reserves_service_info['unitName'],
          'unitPhone' => split_phone_number(reserves_service_info['unitPhone']),
          'receivingInactiveDutyTrainingPay' => input_form['hasTrainingPay']
        }.compact
      end

      def translate_names
        return nil if input_form['alternateNames'].blank?
        input_form['alternateNames'].map do |an|
          {
            'firstName' => an['first'],
            'middleName' => an['middle'],
            'lastName' => an['last']
          }.compact
        end
      end

      def service_branch(service_branch)
        branch_map = {
          'Air Force Reserve' => 'Air Force Reserves',
          'Army Reserve' => 'Army Reserves',
          'Coast Guard Reserve' => 'Coast Guard Reserves',
          'Marine Corps Reserve' => 'Marine Corps Reserves',
          'Navy Reserve' => 'Navy Reserves',
          'NOAA' => 'National Oceanic & Atmospheric Administration'
        }
        return branch_map[service_branch] if branch_map.key? service_branch
        service_branch
      end

      def translate_veteran
        {
          'veteran' => {
            'emailAddress' => input_form.dig('phoneAndEmail', 'emailAddress'),
            'currentMailingAddress' => translate_mailing_address(input_form['mailingAddress']),
            'changeOfAddress' => translate_change_of_address(input_form['forwardingAddress']),
            'daytimePhone' => split_phone_number(input_form.dig('phoneAndEmail', 'primaryPhone')),
            'homelessness' => translate_homelessness,
            'currentlyVAEmployee' => input_form['isVaEmployee']
          }.compact
        }
      end

      def translate_change_of_address(address)
        return nil if address.blank?
        forwarding_address = translate_mailing_address(address)
        forwarding_address['addressChangeType'] = address['effectiveDate']['to'].blank? ? 'PERMANENT' : 'TEMPORARY'
        forwarding_address
      end

      def translate_mailing_address(address)
        pciu_address = {
          'country' => address['country'],
          'addressLine1' => address['addressLine1'],
          'addressLine2' => address['addressLine2'],
          'addressLine3' => address['addressLine3'],
          'beginningDate' => address.dig('effectiveDate', 'from'),
          'endingDate' => address.dig('effectiveDate', 'to')
        }

        pciu_address['type'] = get_address_type(address)

        zip_code = split_zip_code(address['zipCode']) if address['zipCode']

        case pciu_address['type']
        when 'DOMESTIC'
          pciu_address.merge!(set_domestic_address(address, zip_code))
        when 'MILITARY'
          pciu_address.merge!(set_military_address(address, zip_code))
        when 'INTERNATIONAL'
          pciu_address.merge!(set_international_address(address))
        end

        pciu_address.compact
      end

      def get_address_type(address)
        return 'MILITARY' if %w[AA AE AP].include?(address['state'])
        return 'DOMESTIC' if address['country'] == 'USA'
        'INTERNATIONAL'
      end

      def set_domestic_address(address, zip_code)
        {
          'city' => address['city'],
          'state' => address['state'],
          'zipFirstFive' => zip_code.first,
          'zipLastFour' => zip_code.last
        }
      end

      def set_military_address(address, zip_code)
        {
          'militaryPostOfficeTypeCode' => address['city'],
          'militaryStateCode' => address['state'],
          'zipFirstFive' => zip_code.first,
          'zipLastFour' => zip_code.last
        }
      end

      def set_international_address(address)
        postal_codes = JSON.parse(File.read(Settings.evss.international_postal_codes))

        {
          'internationalPostalCode' => postal_codes[address['country']],
          'city' => address['city']
        }
      end

      def split_zip_code(zip_code)
        zip_code.match(/(^\d{5})(?:([-\s]?)(\d{4})?$)/).captures
      end

      def split_phone_number(phone_number)
        return nil if phone_number.blank?
        area_code, number = phone_number.match(/(\d{3})(\d{7})/).captures
        { 'areaCode' => area_code, 'phoneNumber' => number }
      end

      def translate_homelessness
        case input_form['homelessOrAtRisk']
        when 'no' || nil
          nil
        when 'homeless'
          homeless
        when 'atRisk'
          at_risk
        end
      end

      def homeless
        # The form separates the `fleeing` key from the rest and needs to be checked
        situation = input_form['needToLeaveHousing'].present? ? 'fleeing' : input_form['homelessHousingSituation']
        {
          'pointOfContact' => point_of_contact,
          'currentlyHomeless' => {
            'homelessSituationType' => HOMELESS_SITUATION_TYPE[situation],
            'otherLivingSituation' => input_form['otherHomelessHousing']
          }.compact
        }
      end

      def at_risk
        {
          'pointOfContact' => point_of_contact,
          'homelessnessRisk' => {
            'homelessnessRiskSituationType' => HOMELESS_RISK_SITUATION_TYPE[input_form['atRiskHousingSituation']],
            'otherLivingSituation' => input_form['otherAtRiskHousing']
          }.compact
        }
      end

      def point_of_contact
        {
          'pointOfContactName' => input_form['homelessnessContact']['name'],
          'primaryPhone' => split_phone_number(input_form['homelessnessContact']['phoneNumber'])
        }
      end

      def translate_treatments
        return {} if input_form['vaTreatmentFacilities'].blank?

        treatments = input_form['vaTreatmentFacilities'].map do |treatment|
          {
            'startDate' => approximate_date(treatment['treatmentDateRange']['from']),
            'endDate' => approximate_date(treatment['treatmentDateRange']['to']),
            'treatedDisabilityNames' => treatment['treatedDisabilityNames'],
            'center' => {
              'name' => treatment['treatmentCenterName']
            }.merge(treatment['treatmentCenterAddress'])
          }.compact
        end

        { 'treatments' => treatments }
      end

      def approximate_date(date)
        return nil if date.blank?

        year, month, day = date.split('-')

        # month/day are optional and can be XXed out
        month = nil if month == 'XX'
        day = nil if day == 'XX'

        {
          'year' => year,
          'month' => month,
          'day' => day
        }.compact
      end

      def translate_disabilities
        rated_disabilities = input_form['ratedDisabilities'].deep_dup.presence || []
        # New primary disabilities need to be added first before handling secondary
        # disabilities because a new secondary disability can be added to a new
        # primary disability
        primary_disabilities = translate_new_primary_disabilities(rated_disabilities)
        disabilities = translate_new_secondary_disabilities(primary_disabilities)

        # Strip out disabilites with ActionType eq to `None` that do not have any
        # secondary disabilities to avoid sending extraneous data
        disabilities.delete_if do |disability|
          disability['disabilityActionType'] == 'NONE' && disability['secondaryDisabilities'].blank?
        end

        { 'disabilities' => disabilities }
      end

      def translate_new_primary_disabilities(disabilities)
        return disabilities if input_form['newPrimaryDisabilities'].blank?

        input_form['newPrimaryDisabilities'].each do |input_disability|
          # Disabilities that do not exist in the mapped list (disabilities without
          # a classification code) need to be scrubbed of characters not allowed by
          # EVSS's validation.
          if input_disability['classificationCode'].blank?
            input_disability['condition'] = scrub_disability_condition(input_disability['condition'])
          end

          case input_disability['cause']
          when 'NEW'
            disabilities.append(map_new(input_disability))
          when 'WORSENED'
            disabilities.append(map_worsened(input_disability))
          when 'VA'
            disabilities.append(map_va(input_disability))
          end
        end

        disabilities
      end

      def scrub_disability_condition(condition)
        re = %r{([a-zA-Z0-9\-'.,\/() ]+)}
        condition.scan(re).join.squish
      end

      def translate_new_secondary_disabilities(disabilities)
        return disabilities if input_form['newSecondaryDisabilities'].blank?

        input_form['newSecondaryDisabilities'].each do |input_disability|
          disabilities = map_secondary(input_disability, disabilities)
        end

        disabilities
      end

      # Map 'NEW' type disability to EVSS required disability fields
      #
      # @param input_disability [Hash] The newly submitted disability
      # @option input_disability [String] :condition The name of the disability
      # @option input_disability [String] :classificationCode Optional classification code
      # @option input_disability [Array<String>] :specialIssues Optional list of associated special issues
      # @option input_disability [String] :primaryDescription The disabilities description
      # @return [Hash] Transformed disability to match EVSS's validation
      def map_new(input_disability)
        {
          'name' => input_disability['condition'],
          'classificationCode' => input_disability['classificationCode'],
          'disabilityActionType' => 'NEW',
          'specialIssues' => input_disability['specialIssues'].presence,
          'serviceRelevance' => "Caused by an in-service event, injury, or exposure\n"\
                                "#{input_disability['primaryDescription']}"
        }.compact
      end

      # Map 'WORSENED' type disability to EVSS required disability fields
      #
      # @param input_disability [Hash] The newly submitted disability
      # @option input_disability [String] :condition The name of the disability
      # @option input_disability [String] :classificationCode Optional classification code
      # @option input_disability [Array<String>] :specialIssues Optional list of associated special issues
      # @option input_disability [String] :worsenedDescription The disabilities description
      # @option input_disability [String] :worsenedEffects The disabilites effects
      # @return [Hash] Transformed disability to match EVSS's validation
      def map_worsened(input_disability)
        {
          'name' => input_disability['condition'],
          'classificationCode' => input_disability['classificationCode'],
          'disabilityActionType' => 'NEW',
          'specialIssues' => input_disability['specialIssues'].presence,
          'serviceRelevance' => "Worsened because of military service\n"\
                                "#{input_disability['worsenedDescription']}: #{input_disability['worsenedEffects']}"
        }.compact
      end

      # Map 'VA' type disability to EVSS required disability fields
      #
      # @param input_disability [Hash] The newly submitted disability
      # @option input_disability [String] :condition The name of the disability
      # @option input_disability [String] :classificationCode Optional classification code
      # @option input_disability [Array<String>] :specialIssues Optional list of associated special issues
      # @option input_disability [String] :vaMistreatmentDescription The disabilities description
      # @option input_disability [String] :vaMistreatmentLocation The location the disability occurred
      # @option input_disability [String] :vaMistreatmentDate The Date the disability occurred
      # @return [Hash] Transformed disability to match EVSS's validation
      def map_va(input_disability)
        {
          'name' => input_disability['condition'],
          'classificationCode' => input_disability['classificationCode'],
          'disabilityActionType' => 'NEW',
          'specialIssues' => input_disability['specialIssues'].presence,
          'serviceRelevance' => "Caused by VA care\n"\
                                "Event: #{input_disability['vaMistreatmentDescription']}\n"\
                                "Location: #{input_disability['vaMistreatmentLocation']}\n"\
                                "TimeFrame: #{input_disability['vaMistreatmentDate']}"
        }.compact
      end

      # Map 'SECONDARY' type disability to EVSS required disability fields and
      # attach it to preexisting disability
      #
      # @param input_disability [Hash] The newly submitted disability
      # @option input_disability [String] :condition The name of the disability
      # @option input_disability [String] :classificationCode Optional classification code
      # @option input_disability [Array<String>] :specialIssues Optional list of associated special issues
      # @option input_disability [String] :causedByDisabilityDescription The disabilities description
      # @return [Hash] Transformed disability to match EVSS's validation
      def map_secondary(input_disability, disabilities)
        disability = {
          'name' => input_disability['condition'],
          'classificationCode' => input_disability['classificationCode'],
          'disabilityActionType' => 'SECONDARY',
          'specialIssues' => input_disability['specialIssues'].presence,
          'serviceRelevance' => "Caused by a service-connected disability\n"\
                                "#{input_disability['causedByDisabilityDescription']}"
        }.compact

        disabilities.each do |output_disability|
          if output_disability['name'].casecmp(input_disability['causedByDisability']).zero?
            output_disability['secondaryDisabilities'] = [] if output_disability['secondaryDisabilities'].blank?
            output_disability['secondaryDisabilities'].append(disability)
          end
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
