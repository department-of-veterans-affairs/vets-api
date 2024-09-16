# frozen_string_literal: true

module SimpleFormsApi
  module S3
    class SubmissionBuilder < Utils
      attr_reader :file_path, :submission, :attachments, :metadata

      def initialize(benefits_intake_uuid:) # rubocop:disable Lint/MissingSuper
        @submission = FormSubmission.find_by(benefits_intake_uuid:)
        @attachments = []

        raise 'Submission was not found or invalid' unless @submission&.benefits_intake_uuid
        raise 'Submission cannot be built: Only VFF forms are supported' unless vff_form?

        rebuild_submission
      end

      private

      def rebuild_submission
        form_number = vff_forms_map[submission.form_type]
        form = "SimpleFormsApi::#{form_number.titleize.delete(' ')}".constantize.new(form_data_hash)
        filler = SimpleFormsApi::PdfFiller.new(form_number:, form:)

        handle_submission_data(filler, form, form_number)
      end

      def handle_submission_data(filler, form, form_number)
        @file_path = filler.generate(timestamp: submission.created_at).tap do |path|
          validate_metadata(form)
          handle_attachments(form, form_number, path)
        end
      end

      def validate_metadata(form)
        @metadata = SimpleFormsApiSubmission::MetadataValidator.validate(
          form.metadata,
          zip_code_is_us_based: form.zip_code_is_us_based
        )
      end

      def handle_attachments(form, form_number, path)
        if %w[vba_40_0247 vba_40_10007].include?(form_number)
          form.handle_attachments(path)
        elsif form_number == 'vba_20_10207'
          @attachments = form.get_attachments
        end
      end

      def form_data_hash
        @form_data_hash ||= JSON.parse(submission.form_data)
      end

      def vff_forms_map
        SimpleFormsApi::V1::UploadsController::FORM_NUMBER_MAP
      end

      def vff_form?
        vff_forms_map.keys.include?(submission.form_type)
      end
    end
  end
end
