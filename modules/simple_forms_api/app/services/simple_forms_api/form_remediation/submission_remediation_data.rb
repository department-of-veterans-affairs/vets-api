# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class SubmissionRemediationData
      attr_reader :file_path, :submission, :attachments, :metadata

      def initialize(id:, config:)
        @config = config

        validate_input(id)
        fetch_submission(id)

        @attachments = []
        @metadata = {}
      rescue => e
        config.handle_error("#{self.class.name} initialization failed", e)
      end

      def hydrate!
        form_number = fetch_submission_form_number
        form = build_form(form_number)
        filler = PdfFiller.new(form_number:, form:)

        handle_submission_data(filler, form, form_number)
        self
      rescue => e
        config.handle_error('Error hydrating submission', e)
      end

      private

      attr_reader :config

      def validate_input(id)
        raise ArgumentError, "No #{config.id_type} was provided" unless id
      end

      def fetch_submission(id)
        form_submission_attempt = FormSubmissionAttempt.find_by(benefits_intake_uuid: id)
        @submission = form_submission_attempt&.form_submission
        validate_submission
      end

      def validate_submission
        raise 'Submission was not found or invalid' unless submission&.latest_attempt&.send(config.id_type)
        raise "#{self.class} cannot be built: Only VFF forms are supported" unless valid_form?
      end

      def fetch_submission_form_number
        valid_forms_map.fetch(submission.form_type)
      end

      def build_form(form_number)
        form_class_name = "SimpleFormsApi::#{form_number.titleize.delete(' ')}"
        form_class = form_class_name.constantize
        form_class.new(form_data_hash).tap do |form|
          form.signature_date = submission.created_at.in_time_zone('America/Chicago')
        end
      rescue NameError => e
        config.handle_error("Form class not found for #{form_class_name}", e)
      end

      def handle_submission_data(filler, form, form_number)
        @file_path = generate_pdf_file(filler)
        @metadata = validate_metadata(form)
        @attachments = process_attachments(form, form_number)
      end

      def generate_pdf_file(filler)
        filler.generate(timestamp: submission.created_at)
      rescue => e
        config.handle_error('Error generating filled submission PDF', e)
      end

      def validate_metadata(form)
        SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )
      rescue => e
        config.handle_error('Metadata validation failed', e)
      end

      def process_attachments(form, form_number)
        case form_number
        when 'vba_40_0247', 'vba_40_10007'
          form.handle_attachments(file_path)
          []
        when 'vba_20_10207'
          form.get_attachments
        else
          []
        end
      rescue => e
        config.handle_error("Attachment handling failed for #{form_number}", e)
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      rescue JSON::ParserError => e
        config.handle_error('Error parsing form data', e)
      end

      def valid_forms_map
        SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP
      end

      def valid_form?
        valid_forms_map.key?(submission.form_type)
      end
    end
  end
end
