# frozen_string_literal: true

module SimpleFormsApi
  class BenefitsIntakeSubmissionHandler
    include LoggingAndErrorHandling

    VALID_FORMS = %w[
      20-10206 20-10207 21-0845 21-0966 21-0972 21-10210
      21-4138 21-4142 21P-0847 26-4555 40-0247 40-10007
    ].freeze

    def initialize(current_user, form_number:, **kwargs)
      @current_user = current_user
      @form_number = form_number
      @params = kwargs
      @support = SubmissionSupport.new(form_number, current_user, @params)
    rescue => e
      handle_error('Initialization failed', e)
    end

    def submit_form
      parsed_form_data = @support.parse_form_data
      @benefits_intake_uuid, status = @support.handle_pdf_upload

      track_user_identity
      log_info('PDF uploaded successfully', { status:, uuid: @benefits_intake_uuid })

      presigned_s3_url = @support.archive_submission(@benefits_intake_uuid)

      send_confirmation_email(parsed_form_data) if status == 200

      generate_response(status, presigned_s3_url)
    rescue => e
      handle_error('Submission failed', e)
    end

    private

    def send_confirmation_email(parsed_form_data)
      config = {
        form_data: parsed_form_data,
        form_number: @support.form_id,
        confirmation_number: @benefits_intake_uuid,
        date_submitted: Time.zone.today.strftime('%B %d, %Y')
      }
      SimpleFormsApi::NotificationEmail.new(
        config,
        notification_type: :confirmation,
        user: @current_user
      ).send
    end

    def generate_response(status, presigned_s3_url)
      { json: confirmation_payload(presigned_s3_url), status: }
    end

    def confirmation_payload(presigned_s3_url)
      { confirmation_number: @benefits_intake_uuid }.tap do |payload|
        payload[:expiration_date] = 1.year.from_now if @support.form_id == 'vba_21_0966'
        payload[:presigned_s3_url] = presigned_s3_url if presigned_s3_url
      end
    end

    def track_user_identity(confirmation_number)
      form.track_user_identity(confirmation_number)
    end
  end
end
