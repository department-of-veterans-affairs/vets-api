# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionBuilder < Utils
      attr_reader :file_path, :submission, :attachments, :metadata

      def initialize(benefits_intake_uuid:) # rubocop:disable Lint/MissingSuper
        validate_input(benefits_intake_uuid)

        @submission = FormSubmission.find_by(benefits_intake_uuid:)
        validate_submission

        @attachments = []
        @metadata = {}

        hydrate_submission
      rescue => e
        handle_error('SubmissionBuilder initialization failed', e)
      end

      private

      def validate_input(benefits_intake_uuid)
        raise ArgumentError, 'No benefits_intake_uuid was provided' unless benefits_intake_uuid
      end

      def validate_submission
        raise 'Submission was not found or invalid' unless @submission&.benefits_intake_uuid
        raise 'Submission cannot be built: Only VFF forms are supported' unless vff_form?
      end

      def hydrate_submission
        form_number = fetch_submission_form_number
        form = build_form(form_number)

        filler = PdfFiller.new(form_number:, form:)
        handle_submission_data(filler, form, form_number)
      rescue => e
        handle_error('Error rebuilding submission', e)
      end

      def fetch_submission_form_number
        vff_forms_map.fetch(submission.form_type)
      end

      def build_form(form_number)
        form_class = "SimpleFormsApi::#{form_number.titleize.delete(' ')}".constantize
        form_class.new(form_data_hash).tap do |form|
          form.signature_date = submission.created_at.in_time_zone('America/Chicago')
        end
      rescue NameError => e
        handle_error("Form class not found for #{form_number}", e)
      end

      def handle_submission_data(filler, form, form_number)
        @file_path = generate_file(filler)
        validate_metadata(form)
        process_attachments(form, form_number)
      rescue => e
        handle_error('Error handling submission data', e)
      end

      def generate_file(filler)
        filler.generate(timestamp: submission.created_at)
      end

      def validate_metadata(form)
        @metadata = SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )
      rescue => e
        handle_error('Metadata validation failed', e)
      end

      def process_attachments(form, form_number)
        case form_number
        when 'vba_40_0247', 'vba_40_10007'
          form.handle_attachments(file_path)
        when 'vba_20_10207'
          @attachments = form.get_attachments
        end
      rescue => e
        handle_error("Attachment handling failed for #{form_number}", e)
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      rescue JSON::ParserError => e
        handle_error('Error parsing form data', e)
      end

      def vff_forms_map
        SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP
      end

      def vff_form?
        vff_forms_map.key?(submission.form_type)
      end

      def log_error(message, error, **details)
        Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
      end

      def handle_error(message, error, context = {})
        log_error(message, error, **context)
        raise error
      end
    end
  end
end
