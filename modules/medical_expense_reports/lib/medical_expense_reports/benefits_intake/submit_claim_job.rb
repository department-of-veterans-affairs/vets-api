# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'medical_expense_reports/notification_email'
require 'medical_expense_reports/monitor'
require 'pdf_utilities/datestamp_pdf'

require 'bigdecimal'
require 'date'

module MedicalExpenseReports
  module BenefitsIntake
    # Sidekiq job to send pension pdf to Lighthouse:BenefitsIntake API
    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    class SubmitClaimJob
      include Sidekiq::Job

      # Error if "Unable to find MedicalExpenseReports::SavedClaim"
      class MedicalExpenseReportsBenefitIntakeError < StandardError; end

      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      sidekiq_options retry: 16, queue: 'low'
      sidekiq_retries_exhausted do |msg|
        ia_monitor = MedicalExpenseReports::Monitor.new
        begin
          claim = MedicalExpenseReports::SavedClaim.find(msg['args'].first)
        rescue
          claim = nil
        end
        ia_monitor.track_submission_exhaustion(msg, claim)
      end

      ##
      # Process pdfs and upload to Benefits Intake API
      #
      # @param saved_claim_id [Integer] the claim id
      # @param user_account_uuid [UUID] the user submitting the form
      #
      # @return [UUID] benefits intake upload uuid
      #
      def perform(saved_claim_id, user_account_uuid = nil)
        return unless Flipper.enabled?(:medical_expense_reports_form_enabled)

        init(saved_claim_id, user_account_uuid)
        process_submission
      rescue => e
        monitor.track_submission_retry(@claim, @intake_service, @user_account_uuid, e)
        @lighthouse_submission_attempt&.fail!
        raise e
      ensure
        cleanup_file_paths
      end

      private

      ##
      # Handle the document generation, upload flow, and post-submission hooks.
      #
      # @return [String] the intake service UUID for the submission
      def process_submission
        # generate and validate claim pdf documents
        @form_path = process_document(
          @claim.to_pdf(
            @claim.id,
            extras_redesign: true,
            omit_esign_stamp: true
          )
        )
        @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
        form = @claim.parsed_form
        @metadata = generate_metadata(form)
        @ibm_payload = build_ibm_payload(form)

        # upload must be performed within 15 minutes of this request
        upload_document

        send_submitted_email
        monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

        @intake_service.uuid
      end

      # Number of in-home care rows IBM expects.
      IN_HOME_ROW_COUNT = 8

      # Number of medical expense rows IBM expects.
      MED_EXPENSE_ROW_COUNT = 14

      # Number of travel rows IBM expects.
      TRAVEL_ROW_COUNT = 12

      # Normalize values that represent child/dependent recipients.
      CHILD_RECIPIENTS = %w[CHILD DEPENDENT].freeze

      # Instantiate instance variables for _this_ job
      def init(saved_claim_id, user_account_uuid)
        @user_account_uuid = user_account_uuid
        @user_account = UserAccount.find(@user_account_uuid) if @user_account_uuid.present?
        # UserAccount.find will raise an error if unable to find the user_account record

        @claim = MedicalExpenseReports::SavedClaim.find(saved_claim_id)
        unless @claim
          raise MedicalExpenseReportsBenefitIntakeError,
                "Unable to find MedicalExpenseReports::SavedClaim #{saved_claim_id}"
        end

        @intake_service = ::BenefitsIntake::Service.new
      end

      # Create a monitor to be used for _this_ job
      # @see MedicalExpenseReports::Monitor
      def monitor
        @monitor ||= MedicalExpenseReports::Monitor.new
      end

      # Create a temp stamped PDF and validate the PDF satisfies Benefits Intake specification
      #
      # @param [String] file_path
      #
      # @return [String] path to stamped PDF
      def process_document(file_path)
        document = PDFUtilities::DatestampPdf.new(file_path).run(text: 'VA.GOV', x: 5, y: 5)
        document = PDFUtilities::DatestampPdf.new(document).run(
          text: 'FDC Reviewed - VA.gov Submission',
          x: 429,
          y: 770,
          text_only: true
        )

        @intake_service.valid_document?(document:)
      end

      # Generate form metadata to send in upload to Benefits Intake API
      #
      # @see https://developer.va.gov/explore/api/benefits-intake/docs
      # @see SavedClaim.parsed_form
      # @see BenefitsIntake::Metadata
      #
      # @return [Hash]
      # Generate metadata for Benefits Intake upload, deriving veteran and claimant details.
      #
      # @param form [Hash]
      # @return [Hash]
      def generate_metadata(form)
        # also validates/manipulates the metadata
        ::BenefitsIntake::Metadata.generate(
          form['veteranFullName']['first'],
          form['veteranFullName']['last'],
          form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          form['veteranAddress']['postalCode'],
          'va_gov_bio_huntridge',
          @claim.form_id,
          @claim.business_line
        )
      end

      # Build the IBM data dictionary payload from the parsed claim form.
      #
      # @param form [Hash]
      # @return [Hash]
      def build_ibm_payload(form)
        claimant_name = build_name(form['claimantFullName'])
        veteran_name = build_name(form['veteranFullName'])
        primary_phone = form['primaryPhone'] || {}
        reporting_period = form['reportingPeriod'] || {}
        use_va_rcvd_date = use_va_rcvd_date?(form)

        build_claimant_fields(form, claimant_name, primary_phone)
          .merge(build_veteran_fields(veteran_name, form['veteranSocialSecurityNumber']))
          .merge(build_reporting_fields(form, reporting_period, use_va_rcvd_date))
          .merge(build_in_home_fields(form))
          .merge(build_medical_expense_fields(form))
          .merge(build_travel_fields(form))
          .merge(build_witness_fields)
      end

      ##
      # Build the claimant-specific IBM entries (name, address, and contact data).
      #
      # @param form [Hash]
      # @param claimant_name [Hash]
      # @param primary_phone [Hash]
      # @return [Hash]
      def build_claimant_fields(form, claimant_name, primary_phone)
        {
          'CLAIMANT_FIRST_NAME' => claimant_name[:first],
          'CLAIMANT_LAST_NAME' => claimant_name[:last],
          'CLAIMANT_MIDDLE_INITIAL' => claimant_name[:middle_initial],
          'CLAIMANT_NAME' => claimant_name[:full],
          'CLAIMANT_ADDRESS_FULL_BLOCK' => claimant_address_block(form),
          'CLAIMANT_SIGNATURE' => form['statementOfTruthSignature'],
          'CLAIMANT_SIGNATURE_X' => nil,
          'CL_EMAIL' => form['claimantEmail'] || form['email'],
          'CL_INT_PHONE_NUMBER' => international_phone_number(form, primary_phone),
          'CL_PHONE_NUMBER' => claimant_phone_number(form)
        }
      end

      ##
      # Build the veteran-specific IBM entries (name and SSN).
      #
      # @param veteran_name [Hash]
      # @param ssn [String]
      # @return [Hash]
      def build_veteran_fields(veteran_name, ssn)
        {
          'VETERAN_FIRST_NAME' => veteran_name[:first],
          'VETERAN_LAST_NAME' => veteran_name[:last],
          'VETERAN_MIDDLE_INITIAL' => veteran_name[:middle_initial],
          'VETERAN_NAME' => veteran_name[:full],
          'VETERAN_SSN' => ssn
        }
      end

      ##
      # Build the date- and reporting-related IBM entries.
      #
      # @param form [Hash]
      # @param reporting_period [Hash]
      # @param use_va_rcvd_date [Boolean]
      # @return [Hash]
      def build_reporting_fields(form, reporting_period, use_va_rcvd_date)
        {
          'DATE_SIGNED' => claim_date_signed(form),
          'FORM_TYPE' => MedicalExpenseReports::FORM_TYPE_LABEL,
          'MED_EXPENSES_FROM_1' => use_va_rcvd_date ? nil : format_date(reporting_period['from']),
          'MED_EXPENSES_TO_1' => use_va_rcvd_date ? nil : format_date(reporting_period['to']),
          'USE_VA_RCVD_DATE' => use_va_rcvd_date,
          'VA_FILE_NUMBER' => form['vaFileNumber']
        }
      end

      # Normalize a name hash into first, middle/initial, and last strings.
      #
      # @param name_hash [Hash, nil]
      # @return [Hash]
      def build_name(name_hash)
        first = name_hash&.fetch('first', nil)
        middle = name_hash&.fetch('middle', nil)
        last = name_hash&.fetch('last', nil)

        {
          first:,
          last:,
          middle:,
          middle_initial: middle&.slice(0, 1),
          full: [first, middle, last].compact.join(' ').presence
        }
      end

      # Flatten an address hash into a single-line string.
      #
      # @param address [Hash, nil]
      # @return [String, nil]
      def build_address_block(address)
        return unless address

        street_line = [address['street'], address['street2']].compact.join(' ').strip
        city_line = [address['city'], address['state'], address['postalCode']].compact.join(' ').strip
        lines = [street_line, city_line, address['country']].compact_blank
        lines.join(' ').presence
      end

      # Build the claimant address block, falling back to veteran address when needed.
      #
      # @param form [Hash]
      # @return [String, nil]
      def claimant_address_block(form)
        address = form['claimantAddress'] || fallback_claimant_address(form)
        build_address_block(address)
      end

      # Provide a fallback claimant address using the veteran address data.
      #
      # @param form [Hash]
      # @return [Hash, nil]
      def fallback_claimant_address(form)
        veteran_address = form['veteranAddress']
        return unless veteran_address

        {
          'street' => veteran_address['street'],
          'street2' => veteran_address['street2'],
          'city' => veteran_address['city'],
          'state' => veteran_address['state'],
          'postalCode' => veteran_address['postalCode'],
          'country' => veteran_address['country']
        }
      end

      # Format a US phone number as digits only.
      #
      # @param primary_phone [Hash, nil]
      # @return [String, nil]
      def us_phone_number(primary_phone)
        return unless primary_phone&.dig('countryCode')&.casecmp?('US')

        format_phone(primary_phone['contact'])
      end

      # Return the claimant phone number when the country is US.
      #
      # @param form [Hash]
      # @return [String, nil]
      def claimant_phone_number(form)
        primary_phone = form['primaryPhone'] || {}
        number = format_phone(primary_phone['contact'])
        return if number.blank?

        primary_phone['countryCode']&.casecmp?('US') ? number : nil
      end

      # Determine the international phone number field from either explicit internationalPhone or non-US contact.
      #
      # @param form [Hash]
      # @param primary_phone [Hash]
      # @return [String, nil]
      def international_phone_number(form, primary_phone)
        return format_phone(form['internationalPhone']) if form['internationalPhone'].present?
        return format_phone(primary_phone['contact']) unless primary_phone['countryCode']&.casecmp?('US')

        nil
      end

      # Strip a phone string down to digits.
      #
      # @param value [String, nil]
      # @return [String, nil]
      def format_phone(value)
        sanitize_phone(value)
      end

      # Format the signature date for IBM consumption.
      #
      # @param form [Hash]
      # @return [String, nil]
      def claim_date_signed(form)
        format_date(form['dateSigned'] || form['signatureDate'])
      end

      # Strip all non-digit characters from a phone string.
      #
      # @param phone [String, nil]
      # @return [String, nil]
      def sanitize_phone(phone)
        return unless phone

        phone.to_s.gsub(/\D/, '')
      end

      # Determine if the IAM payload should use VA received date.
      #
      # @param form [Hash]
      # @return [Boolean]
      def use_va_rcvd_date?(form)
        form['firstTimeReporting'].presence || false
      end

      # Build the IN_HM_* entries from the careExpenses section.
      #
      # @param form [Hash]
      # @return [Hash]
      def build_in_home_fields(form)
        care_entries = form['careExpenses'] || []
        (1..IN_HOME_ROW_COUNT).each_with_object({}) do |index, hash|
          entry = care_entries[index - 1]
          hash["IN_HM_VTRN_PAID_#{index}"] = recipient_flag(entry, %w[VETERAN])
          hash["IN_HM_SPSE_PAID_#{index}"] = recipient_flag(entry, %w[SPOUSE])
          hash["IN_HM_CHLD_PAID_#{index}"] = recipient_flag(entry, CHILD_RECIPIENTS)
          hash["IN_HM_OTHR_PAID_#{index}"] = recipient_flag(entry, %w[OTHER])
          hash["IN_HM_CHLD_OTHR_NAME_#{index}"] = child_other_name(entry)
          hash["IN_HM_PROVIDER_NAME_#{index}"] = entry&.dig('provider')
          hash["IN_HM_DATE_START_#{index}"] = format_date(entry&.dig('careDate', 'from'))
          hash["IN_HM_DATE_END_#{index}"] = format_date(entry&.dig('careDate', 'to'))
          hash["IN_HM_AMT_PAID_#{index}"] = format_currency(entry&.dig('monthlyAmount'))
          hash["IN_HM_HRLY_RATE_#{index}"] = entry&.dig('hourlyRate')
          hash["IN_HM_NBR_HRS_#{index}"] = entry&.dig('weeklyHours')
        end
      end

      # Build the MED_EXP_* entries from medicalExpenses.
      #
      # @param form [Hash]
      # @return [Hash]
      def build_medical_expense_fields(form)
        entries = form['medicalExpenses'] || []
        (1..MED_EXPENSE_ROW_COUNT).each_with_object({}) do |index, hash|
          entry = entries[index - 1]
          hash["MED_EXP_PAID_VTRN_#{index}"] = recipient_flag(entry, %w[VETERAN])
          hash["MED_EXP_PAID_SPSE_#{index}"] = recipient_flag(entry, %w[SPOUSE])
          hash["MED_EXP_PAID_CHLD_#{index}"] = recipient_flag(entry, CHILD_RECIPIENTS)
          hash["MED_EXP_PAID_OTHR_#{index}"] = recipient_flag(entry, %w[OTHER])
          hash["MED_EXP_CHLD_OTHR_NAME_#{index}"] = child_other_name(entry)
          hash["MED_EXP_DATE_PAID_#{index}"] = format_date(entry&.dig('paymentDate'))
          hash["MED_EXP_AMT_PAID_#{index}"] = format_currency(entry&.dig('paymentAmount'))
          hash["MED_EXP_PRVDR_NAME_#{index}"] = entry&.dig('provider')
          hash["MED_EXPENSE_#{index}"] = entry&.dig('purpose')
          hash.merge!(payment_frequency_fields(entry&.dig('paymentFrequency'), index))
        end
      end

      # Build the travel-related IBM fields from mileageExpenses.
      #
      # @param form [Hash]
      # @return [Hash]
      def build_travel_fields(form)
        entries = form['mileageExpenses'] || []
        (1..TRAVEL_ROW_COUNT).each_with_object({}) do |index, hash|
          entry = entries[index - 1]
          traveler = normalized_traveler(entry)
          hash["VTRN_RQD_TRVL_#{index}"] = traveler_flag(traveler, 'VETERAN', entry)
          hash["SPSE_RQD_TRVL_#{index}"] = traveler_flag(traveler, 'SPOUSE', entry)
          hash["CHLD_RQD_TRVL_#{index}"] = traveler_flag(traveler, 'CHILD', entry)
          hash["OTHR_RQD_TRVL_#{index}"] = traveler_flag(traveler, 'OTHER', entry)
          hash["TRVL_CHLD_OTHR_NAME_#{index}"] = traveler_name_child_other(entry, traveler)
          hash["MDCL_FCLTY_NAME_#{index}"] = travel_location(entry)
          hash["TTL_MLS_TRVLD_#{index}"] = entry&.dig('travelMilesTraveled')
          hash["DATE_TRVLD_#{index}"] = format_date(entry&.dig('travelDate'))
          hash["OTHER_SRC_RMBRSD_#{index}"] = format_currency(entry&.dig('travelReimbursementAmount'))
        end
      end

      # Define placeholders for the witness fields in the IBM payload.
      #
      # @return [Hash]
      def build_witness_fields
        {
          'WITNESS_1_NAME' => nil,
          'WITNESS_1_SIGNATURE' => nil,
          'WITNESS_1_ADDRESS' => nil,
          'WITNESS_2_NAME' => nil,
          'WITNESS_2_ADDRESS' => nil,
          'WITNESS_2_SIGNATURE' => nil
        }
      end

      # Evaluate whether a care or medical entry matches the given recipient types.
      #
      # @param entry [Hash]
      # @param types [Array<String>]
      # @return [Boolean, nil]
      def recipient_flag(entry, types)
        return nil unless entry

        normalized = normalized_recipient(entry)
        return nil unless normalized

        types.include?(normalized)
      end

      # Determine whether a travel entry matches the given traveler type.
      #
      # @param traveler [String, nil]
      # @param type [String]
      # @param entry [Hash]
      # @return [Boolean, nil]
      def traveler_flag(traveler, type, entry)
        return nil unless entry

        traveler == type
      end

      # Return the child/other name when applicable.
      #
      # @param entry [Hash]
      # @return [String, nil]
      def child_other_name(entry)
        recipient = normalized_recipient(entry)
        return nil unless recipient && (CHILD_RECIPIENTS.include?(recipient) || recipient == 'OTHER')

        entry&.dig('recipientName')
      end

      # Determine the location string for travel rows.
      #
      # @param entry [Hash]
      # @return [String, nil]
      def travel_location(entry)
        return nil unless entry

        entry['travelLocationOther'].presence || entry['travelLocation']
      end

      # Return the traveler-specific name for child or other travelers.
      #
      # @param entry [Hash]
      # @param traveler [String, nil]
      # @return [String, nil]
      def traveler_name_child_other(entry, traveler)
        return nil unless entry && %w[CHILD OTHER].include?(traveler)

        entry['travelerName']
      end

      # Normalize recipient values (e.g., DEPENDENT -> CHILD).
      #
      # @param entry [Hash]
      # @return [String, nil]
      def normalized_recipient(entry)
        return unless entry

        value = entry['recipient']
        return unless value

        normalized = value.to_s.strip.upcase
        normalized == 'DEPENDENT' ? 'CHILD' : normalized
      end

      # Normalize traveler values (e.g., DEPENDENT -> CHILD).
      #
      # @param entry [Hash]
      # @return [String, nil]
      def normalized_traveler(entry)
        return unless entry

        value = entry['traveler']
        return unless value

        normalized = value.to_s.strip.upcase
        normalized == 'DEPENDENT' ? 'CHILD' : normalized
      end

      # Translate a payment frequency into the corresponding IBM checkboxes.
      #
      # @param frequency [String, nil]
      # @param index [Integer]
      # @return [Hash]
      def payment_frequency_fields(frequency, index)
        frequency = frequency&.to_s&.strip&.upcase
        {
          "CB_PAYMENT_MONTHLY#{index}" => frequency ? frequency == 'ONCE_MONTH' : nil,
          "CB_PAYMENT_ANNUALLY#{index}" => frequency ? frequency == 'ONCE_YEAR' : nil,
          "CB_PAYMENT_SINGLE#{index}" => frequency ? frequency == 'ONE_TIME' : nil
        }
      end

      # Format a numeric amount for IBM (commas + two decimals).
      #
      # @param value [String, Numeric]
      # @return [String, nil]
      def format_currency(value)
        return unless value

        cleaned = value.to_s.gsub(/[^\d.-]/, '')
        number = BigDecimal(cleaned)
        formatted = format('%.2f', number)
        parts = formatted.split('.')
        whole = parts[0].reverse.scan(/\d{1,3}/).join(',').reverse
        "#{whole}.#{parts[1]}"
      rescue ArgumentError
        nil
      end

      # Normalize a date to MM/DD/YYYY for IBM.
      #
      # @param value [String, Date]
      # @return [String, nil]
      def format_date(value)
        return unless value

        parsed = Date.parse(value.to_s)
        parsed.strftime('%m/%d/%Y')
      rescue ArgumentError
        nil
      end

      # Upload generated pdf to Benefits Intake API
      def upload_document
        @intake_service.request_upload
        monitor.track_submission_begun(@claim, @intake_service, @user_account_uuid)
        lighthouse_submission_polling

        payload = {
          upload_url: @intake_service.location,
          document: @form_path,
          metadata: @metadata.to_json,
          attachments: @attachment_paths
        }
        tracked_payload = payload.merge(
          ibm_payload_present: @ibm_payload.present?,
          ibm_payload_field_count: @ibm_payload&.keys&.count
        )

        monitor.track_submission_attempted(@claim, @intake_service, @user_account_uuid, tracked_payload)
        if Flipper.enabled?(:medical_expense_reports_govcio_mms)
          govcio_upload(payload)
        else
          response = @intake_service.perform_upload(**payload)
          raise MedicalExpenseReportsBenefitIntakeError, response.to_s unless response.success?
        end
      end

      def govcio_upload(payload)
        raise NotImplementedError, 'GovCIO MMS client is not yet implemented'
      end

      # Insert submission polling entries
      def lighthouse_submission_polling
        lighthouse_submission = {
          form_id: @claim.form_id,
          reference_data: @claim.to_json,
          saved_claim: @claim
        }

        Lighthouse::SubmissionAttempt.transaction do
          @lighthouse_submission = Lighthouse::Submission.create(**lighthouse_submission)
          @lighthouse_submission_attempt =
            Lighthouse::SubmissionAttempt.create(submission: @lighthouse_submission,
                                                 benefits_intake_uuid: @intake_service.uuid)
        end

        Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @intake_service.uuid)
      end

      # VANotify job to send Submission in Progress email to veteran
      def send_submitted_email
        MedicalExpenseReports::NotificationEmail.new(@claim.id).deliver(:submitted)
      rescue => e
        monitor.track_send_email_failure(@claim, @intake_service, @user_account_uuid, 'submitted', e)
      end

      # Delete temporary stamped PDF files for this instance.
      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
        @attachment_paths&.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      rescue => e
        monitor.track_file_cleanup_error(@claim, @intake_service, @user_account_uuid, e)
      end
    end
  end
end
