# frozen_string_literal: true

require 'pdf_utilities/datestamp_pdf'
require 'pdf_fill/filler'
require 'logging/call_location'
require 'logging/third_party_transaction'
require 'zero_silent_failures/monitor'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm0781 < Job
      ZSF_DD_TAG_FUNCTION = '526_form_0781_failure_email_queuing'

      extend Logging::ThirdPartyTransaction::MethodWrapper

      attr_reader :submission_id, :evss_claim_id, :uuid

      wrap_with_logging(
        :upload_to_vbms,
        :perform_client_upload,
        additional_class_logs: {
          action: 'upload form 21-0781 to EVSS'
        },
        additional_instance_logs: {
          submission_id: [:submission_id],
          evss_claim_id: [:evss_claim_id],
          uuid: [:uuid]
        }
      )

      FORM_ID_0781 = '21-0781' # form id for PTSD
      FORM_ID_0781A = '21-0781a' # form id for PTSD Secondary to Personal Assault
      FORM_ID_0781V2 = '21-0781V2' # form id for Mental Health Disorder(s) Due to In-Service Traumatic Event(s)

      FORMS_METADATA = {
        FORM_ID_0781 => { docType: 'L228' },
        FORM_ID_0781A => { docType: 'L229' },
        FORM_ID_0781V2 => { docType: 'L228' }
      }.freeze

      STATSD_KEY_PREFIX = 'worker.evss.submit_form0781'

      # Sidekiq has built in exponential back-off functionality for retries
      # A max retry attempt of 16 will result in a run time of ~48 hours
      # This job is invoked from 526 background job
      RETRY = 16

      sidekiq_options retry: RETRY

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']
        timestamp = Time.now.utc
        form526_submission_id = msg['args'].first
        log_info = { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }

        ::Rails.logger.warn('Submit Form 0781 Retries exhausted', log_info)

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

        if Flipper.enabled?(:disability_compensation_use_api_provider_for_0781_uploads)
          submission = Form526Submission.find(form526_submission_id)

          provider = api_upload_provider(submission, FORM_ID_0781)
          provider.log_uploading_job_failure(self, error_class, error_message)
        end

        StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        if Flipper.enabled?(:form526_send_0781_failure_notification)
          EVSS::DisabilityCompensationForm::Form0781DocumentUploadFailureEmail.perform_async(form526_submission_id)
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
          'Failure in SubmitForm0781#sidekiq_retries_exhausted',
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

      def self.api_upload_provider(submission, form_id)
        user = User.find(submission.user_uuid)

        ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:supplemental_document_upload],
          options: {
            form526_submission: submission,
            document_type: FORMS_METADATA[form_id][:docType],
            statsd_metric_prefix: STATSD_KEY_PREFIX
          },
          current_user: user,
          feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_UPLOAD_0781
        )
      end

      # This method generates the PDF documents but does NOT send them anywhere.
      # It just generates them to the filesystem and returns the path to them to be used by other methods.
      #
      # @param submission_id [Integer] The {Form526Submission} id
      # @param uuid [String] The Central Mail UUID, not actually used,
      # but is passed along as the existing process_0781 function requires something here
      # @return [Hash] Returns a hash with the keys
      # `type` (to discern between if it is a 0781 or 0781a form) and
      # `file`, which is the generated file location
      def get_docs(submission_id, uuid)
        @submission_id = submission_id
        @uuid = uuid
        @submission = Form526Submission.find_by(id: submission_id)

        file_type_and_file_objs = []
        {
          'form0781' => FORM_ID_0781,
          'form0781a' => FORM_ID_0781A,
          'form0781v2' => FORM_ID_0781V2
        }.each do |form_type_key, actual_form_types|
          form_content = parsed_forms[form_type_key]

          if form_content.present?
            file_type_and_file_objs << {
              type: actual_form_types,
              file: process_0781(uuid, actual_form_types, form_content, upload: false)
            }
          end
        end
        file_type_and_file_objs
      end

      def parsed_forms
        @parsed_forms ||= JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))
      end

      # Performs an asynchronous job for generating and submitting 0781 + 0781A PDF documents to VBMS
      #
      # @param submission_id [Integer] The {Form526Submission} id
      #
      def perform(submission_id)
        @submission_id = submission_id

        Sentry.set_tags(source: '526EZ-all-claims')
        super(submission_id)

        with_tracking('Form0781 Submission', submission.saved_claim_id, submission.id) do
          # process 0781, 0781a and 0781v2
          {
            'form0781' => FORM_ID_0781,
            'form0781a' => FORM_ID_0781A,
            'form0781v2' => FORM_ID_0781V2
          }.each do |form_key, form_id|
            form_content = parsed_forms[form_key]
            if form_content.present?
              submitted_claim_id = submission.submitted_claim_id
              ::Rails.logger.info('Performing SubmitForm0781', { submission_id:, form_id:, submitted_claim_id: })
              process_0781(submitted_claim_id, form_id, form_content)
            end
          end
        end
      rescue => e
        # Cannot move job straight to dead queue dynamically within an executing job
        # raising error for all the exceptions as sidekiq will then move into dead queue
        # after all retries are exhausted
        retryable_error_handler(e)
        raise e
      end

      private

      def process_0781(evss_claim_id, form_id, form_content, upload: true)
        @evss_claim_id = evss_claim_id
        # generate and stamp PDF file
        pdf_path0781 = generate_stamp_pdf(form_content, evss_claim_id, form_id)
        upload ? upload_to_vbms(pdf_path0781, form_id) : pdf_path0781
      end

      # Invokes Filler ancillary form method to generate PDF document
      # Then calls method PDFUtilities::DatestampPdf to stamp the document.
      # Its called twice, once to stamp with text "VA.gov YYYY-MM-DD" at the bottom of each page
      # and second time to stamp with text "VA.gov Submission" at the top of each page
      def generate_stamp_pdf(form_content, evss_claim_id, form_id)
        submission_date = @submission&.created_at&.in_time_zone('Central Time (US & Canada)')
        form_content = form_content.merge({ 'signatureDate' => submission_date })
        user = OpenStruct.new({ flipper_id: @submission.user_uuid })
        extras_redesign = Flipper.enabled?(:disability_compensation_0781v2_extras_redesign,
                                           user) && form_id == FORM_ID_0781V2
        fill_options = { extras_redesign: }
        pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, evss_claim_id, form_id, fill_options)

        # If extras redesign is enabled, the stamp is added during the fill_ancillary_form call as part of the redesign.
        return pdf_path if extras_redesign

        stamped_path = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.gov Submission', x: 510, y: 775,
                                                                    text_only: true)
        if form_id == FORM_ID_0781V2
          PDFUtilities::DatestampPdf.new(stamped_path).run(
            text: "Signed electronically and submitted via VA.gov at #{format_timestamp(submission_date)}. " \
                  'Signee signed with an identity-verified account.',
            x: 5, y: 5, text_only: true, size: 9
          )
        else
          PDFUtilities::DatestampPdf.new(stamped_path).run(text: 'VA.gov', x: 5, y: 5, timestamp: submission_date)
        end
      end

      # Formats the timestamp for the PDF footer
      def format_timestamp(datetime)
        return nil if datetime.blank?

        utc_time = datetime.utc
        "#{utc_time.strftime('%H:%M')} UTC #{utc_time.strftime('%Y-%m-%d')}"
      end

      def get_evss_claim_metadata(pdf_path, form_id)
        pdf_path_split = pdf_path.split('/')
        {
          doc_type: FORMS_METADATA[form_id][:docType],
          file_name: pdf_path_split.last
        }
      end

      def create_document_data(evss_claim_id, upload_data)
        EVSSClaimDocument.new(
          evss_claim_id:,
          file_name: upload_data[:file_name],
          tracked_item_id: nil,
          document_type: upload_data[:doc_type]
        )
      end

      def upload_to_vbms(pdf_path, form_id)
        upload_data = get_evss_claim_metadata(pdf_path, form_id)
        document_data = create_document_data(evss_claim_id, upload_data)

        raise Common::Exceptions::ValidationErrors, document_data unless document_data.valid?

        # thin wrapper to isolate upload for logging
        file_body = File.read(pdf_path)
        perform_client_upload(file_body, document_data, form_id)
      ensure
        # Delete the temporary PDF file
        File.delete(pdf_path) if pdf_path.present?
      end

      def perform_client_upload(file_body, document_data, form_id)
        if Flipper.enabled?(:disability_compensation_use_api_provider_for_0781_uploads)
          provider = self.class.api_upload_provider(submission, form_id)
          upload_document = provider.generate_upload_document(document_data.file_name)
          provider.submit_upload_document(upload_document, file_body)
        else
          EVSS::DocumentsService.new(submission.auth_headers).upload(file_body, document_data)
        end
      end
    end
  end
end
