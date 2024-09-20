# frozen_string_literal: true

module SimpleFormsApi
  class SubmissionBuilder
    include LoggingAndErrorHandling

    attr_reader :file_path, :submission, :attachments, :metadata

    def initialize(benefits_intake_uuid:)
      validate_input(benefits_intake_uuid)

      @submission = FormSubmission.find_by(benefits_intake_uuid:)
      validate_submission

      support = SubmissionSupport.new(form_number, @submission.user_account&.user, JSON.parse(submission.form_data))

      @file_path = support.file_path
      @metadata = support.metadata
      @attachments = support.attachments
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

    def vff_forms_map
      SimpleFormsApi::BenefitsIntakeSubmissionHandler::FORM_NUMBER_MAP
    end

    def form_number
      vff_forms_map.fetch(submission.form_type)
    end

    def vff_form?
      vff_forms_map.key?(submission.form_type)
    end
  end
end
