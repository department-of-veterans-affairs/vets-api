# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'vets/shared_logging'
require 'logging/third_party_transaction'
require 'sidekiq/form526_job_status_tracker/job_tracker'
require 'sidekiq/form526_job_status_tracker/metrics'

module Lighthouse
  # rubocop:disable Metrics/MethodLength
  class PollForm526PdfError < StandardError; end

  class PollForm526PdfStatus
    def self.update_job_status(form_job_status:, message:, error_class:, error_message:, status:)
      timestamp = Time.now.utc
      form526_submission_id = form_job_status.form526_submission_id
      job_id = form_job_status.job_id
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
        status:,
        bgjob_errors: bgjob_errors.merge(new_error),
        error_class:,
        error_message: message
      )

      ::Rails.logger.warn(
        message,
        { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
      )
    end
  end

  class PollForm526Pdf
    include Sidekiq::Job
    include Sidekiq::Form526JobStatusTracker::JobTracker
    extend ActiveSupport::Concern
    extend Vets::SharedLogging
    extend Logging::ThirdPartyTransaction::MethodWrapper

    attr_accessor :submission_id

    STATSD_KEY_PREFIX = 'worker.lighthouse.poll_form526_pdf'

    wrap_with_logging(
      additional_class_logs: {
        action: 'Begin check for 526 supporting docs'
      },
      additional_instance_logs: {
        submission_id: %i[submission_id]
      }
    )

    sidekiq_options retry_for: 96.hours

    # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
    # :nocov:
    sidekiq_retries_exhausted do |msg, _ex|
      # log, mark Form526JobStatus for submission as "pdf_not_found"
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      form_job_status = Form526JobStatus.find_by(job_id:)

      PollForm526PdfStatus.update_job_status(
        form_job_status:,
        message: 'Poll for Form 526 PDF: Retries exhausted',
        error_class:,
        error_message:,
        status: Form526JobStatus::STATUS[:pdf_not_found]
      )
    rescue => e
      log_exception_to_rails(e)
    end
    # :nocov:

    # Checks claims status for supporting documents for a submission and exits out when found.
    # If the timeout period is exceeded (96 hours), then the 'pdf_not_found' status is written to Form526JobStatus
    #
    # @param submission_id [Integer] The {Form526Submission} id
    #
    def perform(submission_id)
      @submission_id = submission_id

      with_tracking('Form526 Submission', submission.saved_claim_id, submission.id, submission.bdd?) do
        form526_pdf = get_form526_pdf(submission)
        if form526_pdf.present?
          Rails.logger.info('Poll for form 526 PDF: PDF found')
          if Flipper.enabled?(:disability_526_call_received_email_from_polling)
            submission.send_received_email('PollForm526Pdf#perform pdf_found')
          end
          return
        else
          form_job_status = submission.form526_job_statuses.find_by(job_class: 'PollForm526Pdf')
          update_job_status_based_on_age(form_job_status, submission)
        end
      end
    end

    # Evaluate the submission's creation date:
    # - Log a warning if the submission is between 1 and 4 days old.
    # - If the submission is older than 4 days:
    #   - Update the job status to 'pdf_not_found'.
    #   - Exit the job immediately.
    def update_job_status_based_on_age(form_job_status, submission)
      if submission.created_at.between?(DateTime.now - 4.days, DateTime.now - 1.day)
        PollForm526PdfStatus.update_job_status(
          form_job_status:,
          message: 'Poll for form 526 PDF: Submission creation date is over 1 day old for submission_id ' \
                   "#{submission.id}",
          error_class: 'PollForm526PdfError',
          error_message: 'Poll for form 526 PDF: Submission creation date is over 1 day old for submission_id ' \
                         "#{submission.id}",
          status: Form526JobStatus::STATUS[:try]
        )
      elsif submission.created_at <= DateTime.now - 4.days
        PollForm526PdfStatus.update_job_status(
          form_job_status:,
          message: 'Poll for form 526 PDF: Submission creation date is over 4 days old. Exiting...',
          error_class: 'PollForm526PdfError',
          error_message: 'Poll for form 526 PDF: Submission creation date is over 4 days old. Exiting...',
          status: Form526JobStatus::STATUS[:pdf_not_found]
        )
        return
      end
      raise Lighthouse::PollForm526PdfError, 'Poll for form 526 PDF: Keep on retrying!'
    end

    private

    def submission
      @submission ||= Form526Submission.find(@submission_id)
    end

    def get_form526_pdf(submission)
      icn = submission.account.icn
      service = BenefitsClaims::Service.new(icn)
      raw_response = service.get_claim(submission.submitted_claim_id)
      raw_response_body = if raw_response.is_a? String
                            JSON.parse(raw_response)
                          else
                            raw_response
                          end

      supporting_documents = raw_response_body.dig('data', 'attributes', 'supportingDocuments')
      supporting_documents.find do |d|
        d['documentTypeLabel'] == 'VA 21-526 Veterans Application for Compensation or Pension'
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
