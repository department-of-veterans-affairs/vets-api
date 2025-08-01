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
      FORM0781_OVERFLOW_TEXT = "VA Form 0781 has been completed by the applicant and sent to the VBMS eFolder.\n"
      FORM0781A_OVERFLOW_TEXT = "VA Form 0781a has been completed by the applicant and sent to the VBMS eFolder.\n"

      OVERFLOW_TEXT_THRESHOLD = 4000

      VETERAN_FILE_LIST_STATSD_PREFIX = 'api.form_526.overflow_text.veteran_file_list'

      # EVSS validates this date using CST, at some point this may change to EST.
      EVSS_TZ = 'Central Time (US & Canada)'

      def initialize(user, form_content, has_form4142)
        @form_submission_date = Time.now.in_time_zone(EVSS_TZ).to_date
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
        output_form['autoCestPDFGenerationDisabled'] = input_form['autoCestPDFGenerationDisabled'] || false
        output_form['applicationExpirationDate'] = application_expiration_date
        output_form['overflowText'] = overflow_text
        output_form['bddQualified'] = bdd_qualified?
        output_form['claimSubmissionSource'] = 'VA.gov'
        output_form.compact!
        output_form.update(translate_banking_info)
        output_form.update(translate_service_pay)
        output_form.update(translate_service_info)
        output_form.update(translate_veteran)
        output_form.update(translate_treatments)
        output_form.update(translate_disabilities)
        # any form that has a startedFormVersion (whether it is '2019' or '2022')
        # will go through the Toxic Exposure flow
        output_form.update(translate_started_form_version)
        output_form.update(add_toxic_exposure)

        @translated_form
      end

      private

      def redacted(account_number, routing_number)
        account_number&.include?('*') || routing_number&.include?('*')
      end

      def input_form
        @form_content['form526']
      end

      def service_info
        input_form['serviceInformation']
      end

      def output_form
        @translated_form['form526']
      end

      def split_0781_incidents(incidents)
        return nil if incidents.blank?

        incidents.partition { |incident| incident['personalAssault'] }
      end

      def get_form0781_types
        has_v1_form0781 = false
        has_v1_form0781a = false
        if input_form['form0781'].present?
          has_v1_form0781 = true
          incs0781a, incs0781 = split_0781_incidents(input_form['form0781']['incidents'])
          has_v1_form0781a = incs0781a.present?
          has_v1_form0781 = false if has_v1_form0781a && incs0781.empty?
        end
        has_v2_form0781 = input_form['form0781v2'].present?
        { has_form0781: has_v1_form0781 || has_v2_form0781, has_form0781a: has_v1_form0781a }
      end

      def overflow_text
        overflow = ''
        overflow += TERMILL_OVERFLOW_TEXT if input_form['isTerminallyIll'].present?
        overflow += FORM4142_OVERFLOW_TEXT if @has_form4142

        if Flipper.enabled?(:form526_include_document_upload_list_in_overflow_text)
          form0781_content = get_form0781_types
          overflow += FORM0781_OVERFLOW_TEXT if form0781_content[:has_form0781]
          overflow += FORM0781A_OVERFLOW_TEXT if form0781_content[:has_form0781a]

          if input_form['attachments'].present?
            file_guids = input_form['attachments'].pluck('confirmationCode')
            attachments = SupportingEvidenceAttachment.where(guid: file_guids)

            overflow += veteran_attached_files_text(attachments, overflow.length) if attachments.present?
          end
        end

        overflow
      end

      def veteran_attached_files_text(attachments, current_overflow_length)
        attached_files_note = "The veteran uploaded #{attachments.count} documents along with this claim. " \
                              "Please verify in VBMS eFolder.\n"
        filenames_list = list_attachment_filenames(attachments)

        # Display above note only if listing all file names would make notes exceed EVSS overflowText limits
        if (current_overflow_length + attached_files_note.length + filenames_list.length) < OVERFLOW_TEXT_THRESHOLD
          attached_files_note += filenames_list

          StatsD.increment("#{VETERAN_FILE_LIST_STATSD_PREFIX}.included_in_overflow_text")

          Rails.logger.info(
            'Form526 Veteran-attached file names included in overflowText',
            { file_count: attachments.count, user_uuid: @user.uuid, timestamp: Time.now.utc }
          )
        else
          StatsD.increment("#{VETERAN_FILE_LIST_STATSD_PREFIX}.excluded_from_overflow_text")

          Rails.logger.info(
            'Form526 Veteran-attached file names truncated from overflowText',
            { file_count: attachments.count, user_uuid: @user.uuid, timestamp: Time.now.utc }
          )
        end

        attached_files_note
      end

      def list_attachment_filenames(attachments)
        sorted_filenames = attachments.map(&:original_filename).sort

        sorted_filenames.inject('') do |list, filename|
          list + "#{filename}\n"
        end
      end

      ###
      # Banking info
      ###

      def translate_banking_info
        populated = input_form['bankName'].present? && input_form['bankAccountType'].present? &&
                    input_form['bankAccountNumber'].present? && input_form['bankRoutingNumber'].present?
        # If banking data is not included, then it has not changed and will be retrieved from Lighthouse
        if !populated || redacted(input_form['bankAccountNumber'], input_form['bankRoutingNumber'])
          get_banking_info
        else
          direct_deposit(
            input_form['bankAccountType'], input_form['bankAccountNumber'],
            input_form['bankRoutingNumber'], input_form['bankName']
          )
        end
      end

      def get_banking_info
        return {} unless @user.authorize :lighthouse, :direct_deposit_access?

        # Call to Lighthouse Direct Deposit (aka PPIU) data provider
        service = ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:ppiu],
          provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
          options: {},
          current_user: @user,
          feature_toggle: nil
        )

        response = service.get_payment_information

        begin
          set_account(response)
        rescue => e
          method_name = '#get_banking_info'
          Rails.logger.error "#{method_name} Failed to retrieve DirectDeposit data from #{service.class}: #{e.message}"
          raise Common::Exceptions::BadRequest.new(errors: [e.message])
        end
      end

      def set_account(response)
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

      ###
      # Started Form Version
      ###
      def translate_started_form_version
        { 'startedFormVersion' => input_form['startedFormVersion'] || '2019' }
      end

      ###
      # Service pay
      ###

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

      ###
      # Service info
      ###

      def translate_service_info
        service_info = {
          'serviceInformation' => {
            'servicePeriods' => translate_service_periods,
            'confinements' => translate_confinements,
            'reservesNationalGuardService' => translate_national_guard_service,
            'alternateNames' => translate_names
          }.compact
        }

        if days_until_release.positive?
          service_info['serviceInformation']['separationLocationName'] = input_form.dig('serviceInformation',
                                                                                        'separationLocation',
                                                                                        'separationLocationName')
          service_info['serviceInformation']['separationLocationCode'] = input_form.dig('serviceInformation',
                                                                                        'separationLocation',
                                                                                        'separationLocationCode')
        end
        service_info
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

      ###
      # Personal info
      ###

      def translate_names
        return nil if input_form['alternateNames'].blank?

        input_form['alternateNames'].map do |an|
          {
            'firstName' => an['first'],
            'middleName' => an['middle'],
            'lastName' => an['last']
          }.compact
        end.uniq
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

      ###
      # Veteran info
      ###

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
        va_profile_address = {
          'country' => address['country'],
          'addressLine1' => address['addressLine1'],
          'addressLine2' => address['addressLine2'],
          'addressLine3' => address['addressLine3'],
          'beginningDate' => address.dig('effectiveDate', 'from'),
          'endingDate' => address.dig('effectiveDate', 'to')
        }

        va_profile_address['type'] = get_address_type(address)

        zip_code = split_zip_code(address['zipCode']) if address['zipCode']

        case va_profile_address['type']
        when 'DOMESTIC'
          va_profile_address.merge!(set_domestic_address(address, zip_code))
        when 'MILITARY'
          va_profile_address.merge!(set_military_address(address, zip_code))
        when 'INTERNATIONAL'
          va_profile_address.merge!(set_international_address(address))
        end

        va_profile_address.compact
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
          'militaryPostOfficeTypeCode' => address['city']&.strip&.upcase,
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

      ###
      # Treatments
      ###

      def translate_treatments
        return {} if input_form['vaTreatmentFacilities'].blank?

        # treatmentCenterName clean up is an approximation of evss regex
        # validation ([a-zA-Z0-9"\/&\(\)\-'.#]([a-zA-Z0-9(\)\-'.# ])?)+$
        treatments = input_form['vaTreatmentFacilities'].map do |treatment|
          {
            'startDate' => approximate_date(treatment.dig('treatmentDateRange', 'from')),
            'treatedDisabilityNames' => treatment['treatedDisabilityNames'],
            'center' => {
              'name' => treatment['treatmentCenterName'].gsub(/[^a-zA-Z0-9 .()#&'"-]+/, '').gsub(/\s\s+/, ' ').strip
            }.merge(treatment['treatmentCenterAddress'])
          }.compact
        end

        { 'treatments' => treatments }
      end

      def approximate_date(date)
        return nil if date.blank?

        year, month, day = date.split('-')
        return nil if year == 'XXXX'

        # month/day are optional and can be XXed out
        month = nil if month == 'XX'
        day = nil if day == 'XX'

        {
          'year' => year,
          'month' => month,
          'day' => day
        }.compact
      end

      ###
      # Disabilities
      ###

      def translate_disabilities
        rated_disabilities = input_form['ratedDisabilities'].deep_dup.presence || []

        # New primary disabilities need to be added first before handling secondary
        # disabilities because a new secondary disability can be added to a new
        # primary disability
        primary_disabilities = translate_new_primary_disabilities(rated_disabilities)

        # NOTE: currently (4/29/24), the submit transformer in vets-website removes
        # the structured relationship between a secondary disability and its primary.
        # These always come in with cause="NEW", and their relationship reduced to
        # having "Secondary to..." in the primaryDescription. Consequentially, the
        # call to translate_new_secondary_disabilities() is always short-circuited
        disabilities = translate_new_secondary_disabilities(primary_disabilities)

        # Strip out disabilities with ActionType eq to `None` that do not have any
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
          append_input_disability = map_disability(input_disability)

          next if append_input_disability.blank?

          append_input_disability['cause'] = input_disability['cause']
          disabilities.append(append_input_disability)
        end

        disabilities
      end

      def map_disability(input_disability)
        case input_disability['cause']
        when 'NEW'
          append_input_disability = map_new(input_disability)
        when 'WORSENED'
          append_input_disability = map_worsened(input_disability)
        when 'VA'
          append_input_disability = map_va(input_disability)
        end
        append_input_disability
      end

      def scrub_disability_condition(condition)
        re = %r{([a-zA-Z0-9\-'.,/() ]+)}
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
          'serviceRelevance' => "Caused by an in-service event, injury, or exposure\n" \
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
      # @option input_disability [String] :worsenedEffects The disabilities effects
      # @return [Hash] Transformed disability to match EVSS's validation
      def map_worsened(input_disability)
        {
          'name' => input_disability['condition'],
          'classificationCode' => input_disability['classificationCode'],
          'disabilityActionType' => 'NEW',
          'specialIssues' => input_disability['specialIssues'].presence,
          'serviceRelevance' => "Worsened because of military service\n" \
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
          'serviceRelevance' => "Caused by VA care\n" \
                                "Event: #{input_disability['vaMistreatmentDescription']}\n" \
                                "Location: #{input_disability['vaMistreatmentLocation']}\n" \
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
          'serviceRelevance' => "Caused by a service-connected disability\n" \
                                "#{input_disability['causedByDisabilityDescription']}"
        }.compact

        disabilities.each do |output_disability|
          if output_disability['name'].casecmp(input_disability['causedByDisability']).zero?
            output_disability['secondaryDisabilities'] = [] if output_disability['secondaryDisabilities'].blank?
            output_disability['secondaryDisabilities'].append(disability)
          end
        end
      end

      ###
      # Toxic Exposure
      ###

      def add_toxic_exposure
        { 'toxicExposure' => input_form['toxicExposure'] }
      end

      def application_expiration_date
        1.year.from_now.iso8601
      end

      ###
      # Benefits Delivery at Discharge (BDD)
      ###

      def user_supplied_rad_date
        # Retrieve the most recent Release from Active Duty (RAD) date from user supplied service periods
        # Exclude Reserve and Guard unless activated on federal orders
        recent_service_periods_end_dates = translate_service_periods.collect do |episode|
          unless episode['serviceBranch'].include?('Reserve') || episode['serviceBranch'].include?('National Guard')
            episode['activeDutyEndDate']
          end
        end
        recent_service_periods_end_dates << service_info.dig('reservesNationalGuardService', 'title10Activation',
                                                             'anticipatedSeparationDate')
        recent_service_periods_end_dates.compact!
        return nil if recent_service_periods_end_dates.blank?

        recent_service_periods_end_dates.max.in_time_zone(EVSS_TZ).to_date
      end

      def days_until_release
        return 0 unless user_supplied_rad_date

        @days_until_release ||= user_supplied_rad_date - @form_submission_date
      end

      def bdd_qualified?
        # To be bdd_qualified application should be submitted 180-90 days prior to Release from Active Duty (RAD) date.
        # Applications < 90 days prior to release can be submitted but only with value as false.
        if days_until_release > 180
          raise Common::Exceptions::UnprocessableEntity.new(
            detail: 'User may not submit BDD more than 180 days prior to RAD date',
            source: 'DataTranslationAllClaim'
          )
        end
        days_until_release >= 90
      end
    end
  end
end
