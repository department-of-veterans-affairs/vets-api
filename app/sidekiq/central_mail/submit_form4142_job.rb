# frozen_string_literal: true

require 'central_mail/service'
require 'common/exceptions'
require 'evss/disability_compensation_form/metrics'
require 'evss/disability_compensation_form/form4142_processor'
require 'logging/third_party_transaction'

# TODO: Update Namespace once we are 100% done with CentralMail here
module CentralMail
  class SubmitForm4142Job < EVSS::DisabilityCompensationForm::Job
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

      ::Rails.logger.warn(
        'Submit Form 4142 Retries exhausted',
        { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
      )
    rescue => e
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
        handle_service_exception(response) if response.present? && response.status.between?(201, 600)
      end
    rescue => e
      # Cannot move job straight to dead queue dynamically within an executing job
      # raising error for all the exceptions as sidekiq will then move into dead queue
      # after all retries are exhausted
      retryable_error_handler(e)
      raise e
    ensure
      File.delete(@pdf_path) if @pdf_path.present?
    end

    private

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

    def upload_to_lighthouse
      @lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)

      payload = {
        upload_url: @lighthouse_service.location,
        file: { file: @pdf_path, file_name: @pdf_path.split('/').last },
        metadata: generate_metadata.to_json,
        attachments: [] # [ wipn8923 ] TODO: is this better than nil?
      }

      @lighthouse_service.upload_doc(**payload)
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
        'fileNumber' => filenumber # wipn8923 TODO: validate that this is correct
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
  end
end
