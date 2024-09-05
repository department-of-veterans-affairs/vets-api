# frozen_string_literal: true

module SimpleFormsApi
  class BenefitsIntakeClient
    FORM_NUMBER_MAP = {
      '20-10206' => 'vba_20_10206',
      '20-10207' => 'vba_20_10207',
      '21-0845' => 'vba_21_0845',
      '21-0966' => 'vba_21_0966',
      '21-0972' => 'vba_21_0972',
      '21-10210' => 'vba_21_10210',
      '21-4138' => 'vba_21_4138',
      '21-4142' => 'vba_21_4142',
      '21P-0847' => 'vba_21p_0847',
      '26-4555' => 'vba_26_4555',
      '40-0247' => 'vba_40_0247',
      '40-10007' => 'vba_40_10007'
    }.freeze

    def initialize(current_user, form_number:, **kwargs)
      @current_user = current_user
      @form_number = form_number
      @params = kwargs
      @form_id = fetch_form_id
    end

    def submit_form
      parsed_form_data = parse_and_assign_form_data
      status, confirmation_number = upload_pdf

      form.track_user_identity(confirmation_number)
      log_submission(status, confirmation_number)

      send_confirmation_email(parsed_form_data, confirmation_number) if status == 200

      generate_response(confirmation_number, status)
    rescue => e
      handle_submission_error(e)
    end

    private

    attr_accessor :attachments, :file_path, :form_id, :form, :metadata, :params

    def lighthouse_service
      @lighthouse_service ||= BenefitsIntake::Service.new
    end

    def fetch_form_id
      FORM_NUMBER_MAP.fetch(form_number) { raise ArgumentError, "Invalid form_number: #{form_number}" }
    end

    def parse_and_assign_form_data
      parsed_form_data = JSON.parse(params.to_json)
      assign_form_info(parsed_form_data)
      parsed_form_data
    end

    def log_submission(status, uuid)
      Rails.logger.info('PDF was successfully uploaded to benefits intake', { form_number: form_id, status:, uuid: })
    end

    def send_confirmation_email(parsed_form_data, confirmation_number, status)
      return unless status == 200 && Flipper.enabled?(:simple_forms_email_confirmations)

      SimpleFormsApi::ConfirmationEmail.new(
        form_data: parsed_form_data,
        form_number: form_id,
        confirmation_number:,
        user: @current_user
      ).send
    end

    def generate_response(confirmation_number, status)
      { json: get_json(confirmation_number, form_id), status: }
    end

    def assign_form_info(parsed_form_data)
      @form = initialize_form(parsed_form_data)
      @file_path = generate_filled_form
      @metadata = validate_metadata

      handle_form_specific_logic
    end

    def initialize_form(parsed_form_data)
      form_class = "SimpleFormsApi::#{form_id.titleize.gsub(' ', '')}".constantize
      form = form_class.new(parsed_form_data)

      # This path can come about if the user is authenticated and, for some reason, doesn't have a participant_id
      form.populate_veteran_data(@current_user) if form_id == 'vba_21_0966' && preparer_is_veteran?
      form
    end

    def generate_filled_form
      filler = SimpleFormsApi::PdfFiller.new(form_number: form_id, form:)
      @current_user ? filler.generate(@current_user.loa[:current]) : filler.generate
    end

    def validate_metadata
      SimpleFormsApiSubmission::MetadataValidator.validate(
        form.metadata,
        zip_code_is_us_based: form.zip_code_is_us_based
      )
    end

    def preparer_is_veteran?
      params[:preparer_identification] == 'VETERAN' && @current_user
    end

    def handle_form_specific_logic
      if form_id == 'vba_20_10207'
        @attachments = form.get_attachments
      elsif %w[vba_40_0247 vba_40_10007].include?(form_id)
        form.handle_attachments(file_path)
      end
    end

    def upload_pdf
      location, uuid = prepare_for_upload
      log_upload_details(location, uuid)

      response = use_benefits_intake_service? ? perform_pdf_upload(location) : perform_document_upload(location)
      [response.status, uuid]
    end

    def use_benefits_intake_service?
      Flipper.enabled?(:simple_forms_lighthouse_benefits_intake_service)
    end

    def prepare_for_upload
      location, uuid = lighthouse_service.request_upload
      stamp_pdf_with_uuid(uuid)
      create_form_submission_attempt(uuid)
      [location, uuid]
    end

    def stamp_pdf_with_uuid(uuid)
      # Stamp uuid on 40-10007
      pdf_stamper = SimpleFormsApi::PdfStamper.new(stamped_template_path: 'tmp/vba_40_10007-tmp.pdf', form:)
      pdf_stamper.stamp_uuid(uuid)
    end

    def create_form_submission_attempt(uuid)
      form_submission = create_form_submission(uuid)
      FormSubmissionAttempt.create(form_submission:)
    end

    def create_form_submission(uuid)
      FormSubmission.create(
        form_type: form_number,
        benefits_intake_uuid: uuid,
        form_data: params.to_json,
        user_account: @current_user&.user_account
      )
    end

    def log_upload_details(location, uuid)
      Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
      Rails.logger.info('Preparing to upload PDF to benefits intake', { location:, uuid: })
    end

    def perform_pdf_upload(upload_url)
      lighthouse_service.perform_upload(
        metadata: metadata.to_json,
        document: file_path,
        upload_url:,
        attachments:
      )
    end

    def perform_document_upload(upload_url)
      lighthouse_service.upload_doc(
        metadata: metadata.to_json,
        file: file_path,
        upload_url:,
        attachments:
      )
    end

    def handle_submission_error(error)
      Rails.logger.error('Form submission to benefits intake failed', { error: error.message, form_number: form_id })
    end
  end
end
