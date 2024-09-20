# frozen_string_literal: true

module SimpleFormsApi
  class SubmissionSupport
    include LoggingAndErrorHandling

    attr_reader :file_path, :metadata, :attachments

    def initialize(form_number, current_user, params)
      @form_number = form_number
      @current_user = current_user
      @params = params
      @form_id = validate_form_number

      assign_form_info
    rescue => e
      handle_error('SubmissionSupport initialization failed', e)
    end

    private

    def validate_form_number
      raise ArgumentError, "Invalid form_number: #{form_number}" unless valid_form_number?

      "vba_#{@form_number.downcase.tr('-', '_')}"
    end

    def valid_form_number?
      BenefitsIntakeSubmissionHandler::VALID_FORMS.include?(@form_number)
    end

    def assign_form_info
      JSON.parse(@params.to_json) do |parsed_form_data|
        @form = initialize_form(parsed_form_data)
        @file_path = generate_filled_form
        @metadata = validate_metadata
        @attachments = process_attachments
      end
    end

    def initialize_form(parsed_form_data)
      form_class = "SimpleFormsApi::#{@form_id.titleize.gsub(' ', '')}".constantize
      form = form_class.new(parsed_form_data)

      form.populate_veteran_data(@current_user) if @form_id == 'vba_21_0966' && preparer_is_veteran?
      form
    end

    def preparer_is_veteran?
      @params[:preparer_identification] == 'VETERAN' && @current_user
    end

    def generate_filled_form
      filler = SimpleFormsApi::PdfFiller.new(form_number: @form_id, form: @form)
      @current_user ? filler.generate(@current_user.loa[:current]) : filler.generate
    end

    def validate_metadata
      SimpleFormsApiSubmission::MetadataValidator.validate(
        @form.metadata,
        zip_code_is_us_based: @form.zip_code_is_us_based
      )
    end

    def process_attachments
      case @form_id
      when 'vba_40_0247', 'vba_40_10007'
        @form.handle_attachments(@file_path)
        []
      when 'vba_20_10207'
        @form.get_attachments
      else
        []
      end
    rescue => e
      handle_error("Attachment handling failed for #{@form_number}", e)
    end

    def handle_pdf_upload
      location, uuid = prepare_for_upload
      response = perform_pdf_upload(location)
      [uuid, response.status]
    end

    def prepare_for_upload
      log_info('Requesting upload location from Lighthouse')
      location, uuid = lighthouse_service.request_upload
      stamp_pdf_with_uuid(uuid)
      create_form_submission_attempt(uuid)

      [location, uuid]
    end

    def stamp_pdf_with_uuid(uuid)
      pdf_stamper = SimpleFormsApi::PdfStamper.new(stamped_template_path: @file_path, form: @form)
      pdf_stamper.stamp_uuid(uuid)
    end

    def create_form_submission_attempt(uuid)
      @submission = create_form_submission(uuid)
      FormSubmissionAttempt.create(form_submission: @submission)
    end

    def create_form_submission(benefits_intake_uuid)
      FormSubmission.create(
        form_type: @form_number,
        benefits_intake_uuid:,
        form_data: @params.to_json,
        user_account: @current_user&.user_account
      )
    end

    def perform_pdf_upload(upload_url)
      lighthouse_service.perform_upload(
        metadata: @metadata.to_json,
        document: @file_path,
        upload_url:,
        attachments: @attachments
      )
    end

    def archive_submission(benefits_intake_uuid)
      submission_archiver = SimpleFormsApi::S3::SubmissionArchiver.new(
        attachments: @attachments,
        benefits_intake_uuid:,
        file_path: @file_path,
        metadata: @metadata,
        submission: @submission
      )
      submission_archiver.run
    end

    def lighthouse_service
      @lighthouse_service ||= BenefitsIntake::Service.new
    end
  end
end
