# frozen_string_literal: true

require 'central_mail/service'
require 'common/exceptions'
require 'evss/disability_compensation_form/metrics'
require 'evss/disability_compensation_form/form4142_processor'
require 'logging/call_location'
require 'logging/third_party_transaction'
require 'zero_silent_failures/monitor'

# TODO: Update Namespace once we are 100% done with CentralMail here
module CentralMail
  class SubmitForm4142Job < EVSS::DisabilityCompensationForm::Job
    INITIAL_FAILURE_EMAIL = :form526_send_4142_failure_notification
    POLLING_FLIPPER_KEY = :disability_526_form4142_polling_records
    POLLED_FAILURE_EMAIL = :disability_526_form4142_polling_record_failure_email

    FORM4142_FORMSUBMISSION_TYPE = "#{Form526Submission::FORM_526}_#{Form526Submission::FORM_4142}".freeze
    ZSF_DD_TAG_FUNCTION = '526_form_4142_upload_failure_email_queuing'

    extend Logging::ThirdPartyTransaction::MethodWrapper

    # this is required to make instance variables available to logs via
    # the wrap_with_logging method
    attr_accessor :submission_id

    wrap_with_logging(
      :upload_to_central_mail,
      :upload_to_lighthouse,
      additional_instance_logs: {
        submission_id: [:submission_id]
      }
    )

    CENTRAL_MAIL_STATSD_KEY_PREFIX = 'worker.evss.submit_form4142'
    LIGHTHOUSE_STATSD_KEY_PREFIX = 'worker.lighthouse.submit_form4142'

    class BenefitsIntake4142Error   < StandardError; end
    class CentralMailResponseError  < Common::Exceptions::BackendServiceException; end

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc
      form526_submission_id = msg['args'].first

      log_info = { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }

      ::Rails.logger.warn('Submit Form 4142 Retries exhausted', log_info)

      form_job_status = Form526JobStatus.find_by(job_id:)
      bgjob_errors = form_job_status.bgjob_errors || {}
      new_error = {
        "#{timestamp.to_i}": {
          caller_method: __method__.to_s,
          error_class:,
          error_message:,
          timestamp:,
          form526_submission_id:
        }
      }
      form_job_status.update(
        status: Form526JobStatus::STATUS[:exhausted],
        bgjob_errors: bgjob_errors.merge(new_error)
      )

      api_statsd_key = if Flipper.enabled?(:disability_compensation_form4142_supplemental)
                         LIGHTHOUSE_STATSD_KEY_PREFIX
                       else
                         CENTRAL_MAIL_STATSD_KEY_PREFIX
                       end

      StatsD.increment("#{api_statsd_key}.exhausted")

      if Flipper.enabled?(:form526_send_4142_failure_notification)
        EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail.perform_async(form526_submission_id)
      end
      # NOTE: do NOT add any additional code here between the failure email being enqueued and the rescue block.
      # The mailer prevents an upload from failing silently, since we notify the veteran and provide a workaround.
      # The rescue will catch any errors in the sidekiq_retries_exhausted block and mark a "silent failure".
      # This shouldn't happen if an email was sent; there should be no code here to throw an additional exception.
      # The mailer should be the last thing that can fail.
    rescue => e
      cl = caller_locations.first
      call_location = Logging::CallLocation.new(ZSF_DD_TAG_FUNCTION, cl.path, cl.lineno)
      zsf_monitor = ZeroSilentFailures::Monitor.new(Form526Submission::ZSF_DD_TAG_SERVICE)
      user_account_id = begin
        Form526Submission.find(form526_submission_id).user_account_id
      rescue
        nil
      end

      zsf_monitor.log_silent_failure(log_info, user_account_id, call_location:)

      ::Rails.logger.error(
        'Failure in SubmitForm4142#sidekiq_retries_exhausted',
        {
          messaged_content: e.message,
          job_id:,
          submission_id: form526_submission_id,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      raise e
    end

    # Performs an asynchronous job for submitting a Form 4142 to central mail service
    #
    # @param submission_id [Integer] the {Form526Submission} id
    #
    def perform(submission_id)
      @submission_id = submission_id

      Sentry.set_tags(source: '526EZ-all-claims')
      super(submission_id)

      with_tracking('Form4142 Submission', submission.saved_claim_id, submission.id) do
        @pdf_path = processor.pdf_path
        response = upload_to_api
        handle_service_exception(response) if response_can_be_logged(response)
      end
    rescue => e
      # Cannot move job straight to dead queue dynamically within an executing job
      # raising error for all the exceptions as sidekiq will then move into dead queue
      # after all retries are exhausted
      retryable_error_handler(e)
      raise e
    ensure
      File.delete(@pdf_path) if File.exist?(@pdf_path.to_s)
    end

    private

    def response_can_be_logged(response)
      response.present? &&
        response.respond_to?(:status) &&
        response.status.respond_to?(:between?) &&
        response.status.between?(201, 600)
    end

    def processor
      @processor ||= EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, jid)
    end

    def upload_to_api
      if Flipper.enabled?(:disability_compensation_form4142_supplemental)
        upload_to_lighthouse
      else
        upload_to_central_mail
      end
    end

    def upload_to_central_mail
      CentralMail::Service.new.upload(processor.request_body)
    end

    def lighthouse_service
      @lighthouse_service ||= BenefitsIntakeService::Service.new(with_upload_location: true)
    end

    def payload_hash(lighthouse_service_location)
      {
        upload_url: lighthouse_service_location,
        file: { file: @pdf_path, file_name: @pdf_path.split('/').last },
        metadata: generate_metadata.to_json,
        attachments: []
      }
    end

    def upload_to_lighthouse
      log_info = { benefits_intake_uuid: lighthouse_service.uuid, submission_id: @submission_id }

      Rails.logger.info(
        'Successful Form4142 Upload Intake UUID acquired from Lighthouse',
        log_info
      )

      payload = payload_hash(lighthouse_service.location)
      response = lighthouse_service.upload_doc(**payload)

      if Flipper.enabled?(POLLING_FLIPPER_KEY)
        form526_submission = Form526Submission.find(@submission_id)
        form_submission_attempt = create_form_submission_attempt(form526_submission)
        log_info[:form_submission_id] = form_submission_attempt.form_submission.id
      end
      Rails.logger.info('Successful Form4142 Submission to Lighthouse', log_info)
      response
    end

    def generate_metadata
      vet_name = submission.full_name
      filenumber = submission.auth_headers['va_eauth_birlsfilenumber']

      metadata = {
        'veteranFirstName' => vet_name[:first],
        'veteranLastName' => vet_name[:last],
        'zipCode' => determine_zip,
        'source' => 'Form526Submission va.gov',
        'docType' => '4142',
        'businessLine' => '',
        'fileNumber' => filenumber
      }

      SimpleFormsApiSubmission::MetadataValidator
        .validate(metadata, zip_code_is_us_based: usa_based?)
    end

    def determine_zip
      submission.form.dig('form526', 'form526', 'veteran', 'currentMailingAddress', 'zipFirstFive') ||
        submission.form.dig('form526', 'form526', 'veteran', 'mailingAddress', 'zipFirstFive') ||
        '00000'
    end

    def usa_based?
      country =
        submission.form.dig('form526', 'form526', 'veteran', 'currentMailingAddress', 'country') ||
        submission.form.dig('form526', 'form526', 'veteran', 'mailingAddress', 'country')

      %w[USA US].include?(country&.upcase)
    end

    # Cannot move job straight to dead queue dynamically within an executing job
    # raising error for all the exceptions as sidekiq will then move into dead queue
    # after all retries are exhausted
    def handle_service_exception(response)
      error = create_service_error(nil, self.class, response)
      raise error
    end

    def create_service_error(key, source, response, _error = nil)
      response_values = response_values(key, source, response.status, response.body)
      CentralMailResponseError.new(key, response_values, nil, nil)
    end

    def response_values(key, source, status, detail)
      {
        status:,
        detail:,
        code: key,
        source: source.to_s
      }
    end

    def create_form_submission_attempt(form526_submission)
      form_submission = form526_submission.saved_claim.form_submissions.find_by(form_type: FORM4142_FORMSUBMISSION_TYPE)
      if form_submission.blank?
        form_submission = FormSubmission.create(
          form_type: FORM4142_FORMSUBMISSION_TYPE, # form526_form4142
          form_data: '{}', # we have this already in the Form526Submission.form['form4142']
          user_account: form526_submission.user_account,
          saved_claim: form526_submission.saved_claim
        )
      end
      FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: lighthouse_service.uuid)
    end
  end
end
