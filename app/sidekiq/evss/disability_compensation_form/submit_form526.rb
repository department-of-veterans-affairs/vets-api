# frozen_string_literal: true

require 'evss/disability_compensation_form/service_exception'
require 'evss/disability_compensation_form/gateway_timeout'
require 'evss/disability_compensation_form/form526_to_lighthouse_transform'
require 'sentry_logging'
require 'logging/third_party_transaction'
require 'sidekiq/form526_job_status_tracker/job_tracker'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526 < Job
      extend Logging::ThirdPartyTransaction::MethodWrapper

      attr_accessor :submission_id

      # Sidekiq has built in exponential back-off functionality for retries
      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      RETRY = 16
      STATSD_KEY_PREFIX = 'worker.evss.submit_form526'

      wrap_with_logging(
        :submit_complete_form,
        additional_class_logs: {
          action: 'Begin overall 526 submission'
        },
        additional_instance_logs: {
          submission_id: %i[submission_id]
        }
      )

      sidekiq_options retry: RETRY, queue: 'low'

      # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
      # :nocov:
      sidekiq_retries_exhausted do |msg, _ex|
        submission = nil
        next_birls_jid = nil

        # log, mark Form526JobStatus for submission as "exhausted"
        begin
          job_exhausted(msg, STATSD_KEY_PREFIX)
        rescue => e
          log_exception_to_sentry(e)
        end

        # Submit under different birls if avail
        begin
          submission = Form526Submission.find msg['args'].first
          next_birls_jid = submission.submit_with_birls_id_that_hasnt_been_tried_yet!(
            silence_errors_and_log_to_sentry: true,
            extra_content_for_sentry: { job_class: msg['class'].demodulize, job_id: msg['jid'] }
          )
        rescue => e
          log_exception_to_sentry(e)
        end

        # if no more unused birls to attempt submit with, give up, let vet know
        begin
          notify_enabled = Flipper.enabled?(:disability_compensation_pif_fail_notification)
          if submission && next_birls_jid.nil? && msg['error_message'] == 'PIF in use' && notify_enabled
            first_name = submission.get_first_name&.capitalize || 'Sir or Madam'
            params = submission.personalization_parameters(first_name)
            Form526SubmissionFailedEmailJob.perform_async(params)
          end
        rescue => e
          log_exception_to_sentry(e)
        end
      end
      # :nocov:

      # Performs an asynchronous job for submitting a form526 to an upstream
      # submission service (currently EVSS)
      #
      # @param submission_id [Integer] The {Form526Submission} id
      def perform(submission_id)
        Sentry.set_tags(source: '526EZ-all-claims')
        super(submission_id)

        return if fail_submission_feature_enabled?(submission)

        # This instantiates the service as defined by the inheriting object
        # TODO: this meaningless variable assignment is required for the specs to pass, which
        # indicates a problematic coupling of implementation and test logic.  This should eventually
        # be addressed to make this service and test more robust and readable.
        service = service(submission.auth_headers)

        with_tracking('Form526 Submission', submission.saved_claim_id, submission.id, submission.bdd?,
                      service_provider) do
          submission.mark_birls_id_as_tried!

          return unless successfully_prepare_submission_for_evss?(submission)

          begin
            response = choose_service_provider(submission, service)
            response_handler(response)
            send_post_evss_notifications(submission, true)
          rescue => e
            send_post_evss_notifications(submission, false)
            handle_errors(submission, e)
          end
        end
      end

      private

      # send submission data to either EVSS or Lighthouse (LH)
      def choose_service_provider(submission, service)
        if submission.claims_api? # not needed once fully migrated to LH
          send_submission_data_to_lighthouse(submission, submission.account.icn)
        else
          service.submit_form526(submission.form_to_json(Form526Submission::FORM_526))
        end
      end

      def service_provider
        submission.claims_api? ? 'lighthouse' : 'evss'
      end

      def fail_submission_feature_enabled?(submission)
        if Flipper.enabled?(:disability_compensation_fail_submission,
                            OpenStruct.new({ flipper_id: submission.user_uuid }))
          with_tracking('Form526 Submission', submission.saved_claim_id, submission.id, submission.bdd?) do
            Rails.logger.info("disability_compensation_fail_submission enabled for submission #{submission.id}")
            throw StandardError
          rescue => e
            handle_errors(submission, e)
            true
          end
        end
      end

      def successfully_prepare_submission_for_evss?(submission)
        submission.prepare_for_evss!
        true
      rescue => e
        handle_errors(submission, e)
        false
      end

      def send_submission_data_to_lighthouse(submission, icn)
        # 1. transform submission data to LH format
        transform_service = EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
        transaction_id = submission.system_transaction_id
        body = transform_service.transform(submission.form['form526'])
        # 2. send transformed submission data to LH endpoint
        benefits_claims_service = BenefitsClaims::Service.new(icn)
        raw_response = benefits_claims_service.submit526(body, nil, nil, { transaction_id: })
        raw_response_body = if raw_response.body.is_a? String
                              JSON.parse(raw_response.body)
                            else
                              raw_response.body
                            end
        # 3. convert LH raw response to a FormSubmitResponse for further processing (claim_id, status)
        # parse claimId from LH response
        submitted_claim_id = raw_response_body.dig('data', 'attributes', 'claimId').to_i
        raw_response_struct = OpenStruct.new({
                                               body: { claim_id: submitted_claim_id },
                                               status: raw_response.status
                                             })
        EVSS::DisabilityCompensationForm::FormSubmitResponse.new(raw_response_struct.status, raw_response_struct)
      end

      def submit_complete_form
        service.submit_form526(submission.form_to_json(Form526Submission::FORM_526))
      end

      def response_handler(response)
        submission.submitted_claim_id = response.claim_id
        submission.save
        # send "Submitted" email with claim id here for primary path
        submission.send_submitted_email("#{self.class}#response_handler primary path")
      end

      def send_post_evss_notifications(submission, send_notifications)
        actor = OpenStruct.new({ flipper_id: submission.user_uuid })
        if Flipper.enabled?(:disability_compensation_production_tester, actor)
          Rails.logger.info("send_post_evss_notifications call skipped for submission #{submission.id}")
        elsif send_notifications
          submission.send_post_evss_notifications!
        end
      rescue => e
        handle_errors(submission, e)
      end

      def handle_errors(submission, error)
        error = retries_will_fail_error(error)
        raise error
      rescue Common::Exceptions::BackendServiceException,
             Common::Exceptions::Unauthorized, # 401 (UnauthorizedError?)
             # 422 (UpstreamUnprocessableEntity, i.e. EVSS container validation)
             Common::Exceptions::UpstreamUnprocessableEntity,
             Common::Exceptions::TooManyRequests, # 429
             Common::Exceptions::ClientDisconnected, # 499
             Common::Exceptions::ExternalServerInternalServerError, # 500
             Common::Exceptions::NotImplemented, # 501
             Common::Exceptions::BadGateway, # 502
             Common::Exceptions::ServiceUnavailable, # 503 (ServiceUnavailableException)
             Common::Exceptions::GatewayTimeout, # 504
             Breakers::OutageException => e
        retryable_error_handler(submission, e)
      rescue EVSS::DisabilityCompensationForm::ServiceException => e
        # retry submitting the form for specific upstream errors
        retry_form526_error_handler!(submission, e)
      rescue => e
        non_retryable_error_handler(submission, e)
      end

      # check if this error from the provider will fail retires
      def retries_will_fail_error(error)
        if error.instance_of?(Common::Exceptions::UnprocessableEntity)
          error_clone = error.deep_dup
          upstream_error = error_clone.errors.first.stringify_keys
          unless (upstream_error['source'].present? && upstream_error['source']['pointer'].present?) ||
                 upstream_error['detail'].downcase.include?('retries will fail')
            error = Common::Exceptions::UpstreamUnprocessableEntity.new(errors: error.errors)
          end
        end
        error
      end

      def retryable_error_handler(_submission, error)
        # update JobStatus, log and metrics in JobStatus#retryable_error_handler
        super(error)
        raise error
      end

      def non_retryable_error_handler(submission, error)
        # update JobStatus, log and metrics in JobStatus#non_retryable_error_handler
        super(error)
        unless Flipper.enabled?(:disability_compensation_production_tester,
                                OpenStruct.new({ flipper_id: submission.user_uuid })) ||
               Flipper.enabled?(:disability_compensation_fail_submission,
                                OpenStruct.new({ flipper_id: submission.user_uuid }))
          submission.submit_with_birls_id_that_hasnt_been_tried_yet!(
            silence_errors_and_log_to_sentry: true,
            extra_content_for_sentry: { job_class: self.class.to_s.demodulize, job_id: jid }
          )
        end
      end

      def send_rrd_alert(submission, error, subtitle)
        message = "RRD could not submit the claim to EVSS: #{subtitle}<br/>"
        submission.send_rrd_alert_email("RRD submission to EVSS error: #{subtitle}", message, error)
      end

      def service(_auth_headers)
        raise NotImplementedError, 'Subclass of SubmitForm526 must implement #service'
      end

      # Logic for retrying a job due to an upstream service error.
      # Retry if any upstream external service unavailability exceptions (unless it is caused by an invalid EP code)
      # and any PIF-in-use exceptions are encountered.
      # Otherwise the job is marked as non-retryable and completed.
      #
      # @param error [EVSS::DisabilityCompensationForm::ServiceException]
      #
      def retry_form526_error_handler!(submission, error)
        if error.retryable?
          retryable_error_handler(submission, error)
        else
          non_retryable_error_handler(submission, error)
        end
      end
    end
  end
end
