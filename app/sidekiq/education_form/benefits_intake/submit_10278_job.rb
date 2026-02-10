# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_intake/metadata'

module EducationForm
  module BenefitsIntake
    class Submit10278Job
      include Sidekiq::Job

      class Submit10278JobError < StandardError; end

      FORM_ID = '22-10278'
      STATSD_KEY_PREFIX = 'worker.education_form.benefits_intake.submit_10278'

      sidekiq_options retry: 16, queue: 'low'

      sidekiq_retries_exhausted do |msg, _ex|
        claim_id = msg['args'].first
        claim = SavedClaim::EducationBenefits::VA10278.find_by(id: claim_id)

        if claim
          Rails.logger.error(
            "EducationForm::BenefitsIntake::Submit10278Job exhausted retries for claim #{claim_id}",
            { claim_id:, form_id: FORM_ID, confirmation_number: claim.confirmation_number }
          )
          StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        else
          Rails.logger.error(
            'EducationForm::BenefitsIntake::Submit10278Job exhausted retries - claim not found',
            { claim_id:, form_id: FORM_ID }
          )
        end
      end

      def perform(saved_claim_id, user_account_uuid = nil)
        init(saved_claim_id, user_account_uuid)

        return if lighthouse_submission_pending_or_success?

        @form_path = generate_pdf
        @metadata = generate_metadata

        upload_to_benefits_intake
        log_submission_success(saved_claim_id)

        @intake_service.uuid
      rescue => e
        handle_submission_failure(saved_claim_id, e)
        raise e
      ensure
        cleanup_file_paths
      end

      private

      def init(saved_claim_id, user_account_uuid)
        @user_account_uuid = user_account_uuid
        @claim = SavedClaim::EducationBenefits::VA10278.find(saved_claim_id)
        @intake_service = ::BenefitsIntake::Service.new
      end

      def lighthouse_submission_pending_or_success?
        @claim&.lighthouse_submissions&.any? do |lighthouse_submission|
          lighthouse_submission.non_failure_attempt.present?
        end || false
      end

      def generate_pdf
        @claim.to_pdf
      end

      def generate_metadata
        form = @claim.parsed_form
        claimant_info = form['claimantPersonalInformation'] || {}
        full_name = claimant_info['fullName'] || {}
        address = form['claimantAddress'] || {}

        first_name = full_name['first']
        last_name = full_name['last']
        file_number = claimant_info['vaFileNumber'] || claimant_info['ssn']
        zip_code = address['zipCode'] || address['postalCode']

        ::BenefitsIntake::Metadata.generate(
          first_name,
          last_name,
          file_number,
          zip_code,
          self.class.to_s,
          FORM_ID,
          @claim.business_line
        )
      end

      def upload_to_benefits_intake
        @intake_service.request_upload
        create_lighthouse_submission_records

        payload = {
          upload_url: @intake_service.location,
          document: @form_path,
          metadata: @metadata.to_json
        }

        response = @intake_service.perform_upload(**payload)
        raise Submit10278JobError, "Benefits Intake upload failed: #{response}" unless response.success?

        @lighthouse_submission_attempt.success!
      end

      def create_lighthouse_submission_records
        lighthouse_submission_params = {
          form_id: FORM_ID,
          reference_data: @claim.to_json,
          saved_claim: @claim
        }

        Lighthouse::SubmissionAttempt.transaction do
          @lighthouse_submission = Lighthouse::Submission.create!(**lighthouse_submission_params)
          @lighthouse_submission_attempt = Lighthouse::SubmissionAttempt.create!(
            submission: @lighthouse_submission,
            benefits_intake_uuid: @intake_service.uuid
          )
        end

        Datadog::Tracing.active_trace&.set_tag('benefits_intake_uuid', @intake_service.uuid)
      end

      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(@form_path) if @form_path
      rescue => e
        Rails.logger.error(
          "#{self.class.name} failed to cleanup file",
          { claim_id: @claim&.id, file_path: @form_path, error: e.message }
        )
      end

      def log_submission_success(claim_id)
        StatsD.increment("#{STATSD_KEY_PREFIX}.success")
        Rails.logger.info(
          "#{self.class.name} submission success",
          { claim_id:, benefits_intake_uuid: @intake_service.uuid }
        )
      end

      def handle_submission_failure(claim_id, error)
        @lighthouse_submission_attempt&.fail!
        StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
        Rails.logger.error(
          "#{self.class.name} submission failed",
          { claim_id:, error: error.message }
        )
      end
    end
  end
end
