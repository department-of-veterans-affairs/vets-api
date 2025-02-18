# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'
require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  module V0
    class RepresentativeFormUploadController < ApplicationController
      skip_after_action :verify_pundit_authorization

      def submit
        # debugger
        # Datadog::Tracing.active_trace&.set_tag('form_id', params[:form_number])
        # check_for_changes

        # status, confirmation_number = upload_response

        # send_confirmation_email(params, confirmation_number) if status == 200

        # render json: { status:, confirmation_number: }
      end

      def upload_scanned_form
        # debugger
        # VetsJsonSchema::SCHEMAS["21-686C"]
        attachment = PersistentAttachments::VAForm.new
        attachment.form_id = params['form_id']
        attachment.file = params['file']
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        # debugger
        # render json: { message: "Thank You" }, status: 200
        render json: PersistentAttachmentVAFormSerializer.new(attachment)
      end

      private

      def lighthouse_service
        @lighthouse_service ||= BenefitsIntake::Service.new
      end

      def upload_response
        file_path = find_attachment_path(params[:confirmation_code])
        stamper = PdfStamper.new(stamped_template_path: file_path, current_loa: @current_user.loa[:current],
                                 timestamp: Time.current)
        stamper.stamp_pdf
        metadata = validated_metadata
        status, confirmation_number = upload_pdf(file_path, metadata)
        file_size = File.size(file_path).to_f / (2**20)

        Rails.logger.info(
          'Simple forms api - scanned form uploaded',
          { form_number: params[:form_number], status:, confirmation_number:, file_size: }
        )
        [status, confirmation_number]
      end

      def find_attachment_path(confirmation_code)
        PersistentAttachment.find_by(guid: confirmation_code).to_pdf.to_s
      end

      def validated_metadata
        raw_metadata = {
          'veteranFirstName' => params.dig(:form_data, :full_name, :first),
          'veteranLastName' => params.dig(:form_data, :full_name, :last),
          'fileNumber' => params.dig(:form_data, :id_number, :ssn) ||
                          params.dig(:form_data, :id_number, :va_file_number),
          'zipCode' => params.dig(:form_data, :postal_code),
          'source' => 'VA Platform Digital Forms',
          'docType' => params[:form_number],
          'businessLine' => 'CMP'
        }
        SimpleFormsApiSubmission::MetadataValidator.validate(raw_metadata)
      end

      def upload_pdf(file_path, metadata)
        location, uuid = prepare_for_upload
        log_upload_details(location, uuid)
        response = perform_pdf_upload(location, file_path, metadata)
        [response.status, uuid]
      end

      def prepare_for_upload
        location, uuid = lighthouse_service.request_upload
        create_form_submission_attempt(uuid)

        [location, uuid]
      end

      def create_form_submission_attempt(uuid)
        FormSubmissionAttempt.transaction do
          form_submission = create_form_submission
          FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: uuid)
        end
      end

      def create_form_submission
        FormSubmission.create(
          form_type: params[:form_number],
          form_data: params[:form_data].to_json,
          user_account: @current_user&.user_account
        )
      end

      def log_upload_details(location, uuid)
        Datadog::Tracing.active_trace&.set_tag('uuid', uuid)
        Rails.logger.info('Simple forms api - preparing to upload scanned PDF to benefits intake', { location:, uuid: })
      end

      def perform_pdf_upload(location, file_path, metadata)
        lighthouse_service.perform_upload(
          metadata: metadata.to_json,
          document: file_path,
          upload_url: location
        )
      end

      def check_for_changes
        # debugger
        in_progress_form = InProgressForm.form_for_user('FORM-UPLOAD-FLOW', @current_user)
        if in_progress_form
          prefill_data_service = SimpleFormsApi::PrefillDataService.new(prefill_data: in_progress_form.form_data,
                                                                        form_data: params[:form_data],
                                                                        form_id: params[:form_number])
          prefill_data_service.check_for_changes
        end
      end

      def send_confirmation_email(params, confirmation_number)
        config = {
          form_number: params[:form_number],
          form_data: params[:form_data],
          date_submitted: Time.zone.today.strftime('%B %d, %Y'),
          confirmation_number:
        }
        notification_email = SimpleFormsApi::FormUploadNotificationEmail.new(config, notification_type: :confirmation)
        notification_email.send
      end

      def form_params
        params.require(:scanned_form_upload).permit(
          :confirmation_code,
          :location,
          :form_number,
          :form_name,
          form_data: [
            :email,
            :postal_code,
            { full_name: %i[first last],
              id_number: [:ssn] }
          ]
        )
      end

      def ssn
        form_params.dig('form_data', 'id_number', 'ssn')
      end

      def first_name
        form_params.dig('form_data', 'full_name', 'first')
      end

      def last_name
        form_params.dig('form_data', 'full_name', 'last')
      end

      def birth_date
        '02/05/1932'
        # form_params.dig("form_data", "full_name", "date_of_birth")
      end

      # def validate_power_of_attorney
      # icn = get_icn
      # debugger
      # power_of_attorney_attributes = get_power_of_attorney_attributes(icn)

      # debugger
      # rep_poa_codes = get_rep_poa_codes
      # raise if !rep_poa_codes.include?(power_of_attorney_attributes["code"])
      #  || !(power_of_attorney_agreement["name"].downcase == common_name.downcase)
      # debugger

      # end

      # def get_icn
      #   mpi = MPI::Service.new.find_profile_by_attributes(ssn:, first_name:, last_name:, birth_date:)
      #   raise if mpi.profile.nil?
      #   icn = mpi.profile.icn
      # end

      # def get_power_of_attorney_attributes(icn)
      #   response = BenefitsClaims::Service.new(icn).get_power_of_attorney
      #   attributes = response["data"]["attributes"]
      #   raise if attrubtes.nil?
      #   attributes
      # end

      # def get_rep_poa_codes
      # ar_user_account_accredited_individuals
      # ["589"]
      # end
      # end
    end
  end
end
