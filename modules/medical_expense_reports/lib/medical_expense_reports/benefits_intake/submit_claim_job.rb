# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'
require 'medical_expense_reports/notification_email'
require 'medical_expense_reports/monitor'
require 'pdf_utilities/datestamp_pdf'

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

        # generate and validate claim pdf documents
        @form_path = process_document(@claim.to_pdf(@claim.id, { extras_redesign: true,
                                                                 omit_esign_stamp: true }))
        @attachment_paths = @claim.persistent_attachments.map { |pa| process_document(pa.to_pdf) }
        form = @claim.parsed_form
        @metadata = generate_metadata(form)
        @ibm_payload = build_ibm_payload(form)

        # upload must be performed within 15 minutes of this request
        upload_document

        send_submitted_email
        monitor.track_submission_success(@claim, @intake_service, @user_account_uuid)

        @intake_service.uuid
      rescue => e
        monitor.track_submission_retry(@claim, @intake_service, @user_account_uuid, e)
        @lighthouse_submission_attempt&.fail!
        raise e
      ensure
        cleanup_file_paths
      end

      private

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
      def generate_metadata(form)

        # also validates/maniuplates the metadata
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

      def build_ibm_payload(form)
        claimant_name = build_name(form['claimantFullName'])
        veteran_name = build_name(form['veteranFullName'])
        primary_phone = form['primaryPhone'] || {}
        reporting_period = form['reportingPeriod'] || {}
        use_va_rcvd_date = use_va_rcvd_date?(form)

        {
          'CLAIMANT_FIRST_NAME' => claimant_name[:first],
          'CLAIMANT_LAST_NAME' => claimant_name[:last],
          'CLAIMANT_MIDDLE_INITIAL' => claimant_name[:middle_initial],
          'CLAIMANT_NAME' => claimant_name[:full],
          'CLAIMANT_ADDRESS_FULL_BLOCK' => build_address_block(form['claimantAddress']),
          'CLAIMANT_SIGNATURE' => form['statementOfTruthSignature'],
          'CLAIMANT_SIGNATURE_X' => nil,
          'CL_EMAIL' => form['claimantEmail'] || form['email'],
          'CL_INT_PHONE_NUMBER' => international_phone_number(form, primary_phone),
          'CL_PHONE_NUMBER' => us_phone_number(primary_phone),
          'DATE_SIGNED' => form['dateSigned'],
          'FORM_TYPE' => MedicalExpenseReports::FORM_ID,
          'MED_EXPENSES_FROM_1' => use_va_rcvd_date ? nil : reporting_period['from'],
          'MED_EXPENSES_TO_1' => use_va_rcvd_date ? nil : reporting_period['to'],
          'USE_VA_RCVD_DATE' => use_va_rcvd_date,
          'VA_FILE_NUMBER' => form['vaFileNumber'],
          'VETERAN_FIRST_NAME' => veteran_name[:first],
          'VETERAN_LAST_NAME' => veteran_name[:last],
          'VETERAN_MIDDLE_INITIAL' => veteran_name[:middle_initial],
          'VETERAN_NAME' => veteran_name[:full],
          'VETERAN_SSN' => form['veteranSocialSecurityNumber']
        }
      end

      def build_name(name_hash)
        first = name_hash&.fetch('first', nil)
        middle = name_hash&.fetch('middle', nil)
        last = name_hash&.fetch('last', nil)

        {
          first: first,
          last: last,
          middle: middle,
          middle_initial: middle&.slice(0, 1),
          full: [first, middle, last].compact.join(' ').presence
        }
      end

      def build_address_block(address)
        return unless address

        lines = []
        street_line = [address['street'], address['street2']].compact.join(' ').strip
        lines << street_line unless street_line.blank?
        city_line = [address['city'], address['state'], address['postalCode']].compact.join(' ').strip
        lines << city_line unless city_line.blank?
        lines << address['country'] if address['country'].present?

        lines.join("\n").presence
      end

      def us_phone_number(primary_phone)
        return unless primary_phone['countryCode']&.casecmp?('US')

        sanitize_phone(primary_phone['contact'])
      end

      def international_phone_number(form, primary_phone)
        return form['internationalPhone'] if form['internationalPhone'].present?
        return sanitize_phone(primary_phone['contact']) unless primary_phone['countryCode']&.casecmp?('US')

        nil
      end

      def sanitize_phone(phone)
        return unless phone

        phone.to_s.gsub(/\D/, '')
      end

      def use_va_rcvd_date?(form)
        form['firstTimeReporting'].present? ? form['firstTimeReporting'] : false
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
        tracked_payload = payload.merge(ibm_payload: @ibm_payload)

        monitor.track_submission_attempted(@claim, @intake_service, @user_account_uuid, tracked_payload)
        response = @intake_service.perform_upload(**payload)
        raise MedicalExpenseReportsBenefitIntakeError, response.to_s unless response.success?
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
