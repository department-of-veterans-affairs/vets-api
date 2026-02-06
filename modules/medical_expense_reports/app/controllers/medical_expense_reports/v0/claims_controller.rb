# frozen_string_literal: true

require 'medical_expense_reports/benefits_intake/submit_claim_job'
require 'medical_expense_reports/monitor'
require 'medical_expense_reports/zsf_config'
require 'persistent_attachments/sanitizer'

module MedicalExpenseReports
  module V0
    ###
    # The Medical Expense Reports claim controller that handles form submissions
    #
    class ClaimsController < ClaimsBaseController
      include PdfS3Operations

      before_action :check_flipper_flag
      skip_after_action :set_csrf_header, only: [:create]
      service_tag 'medical-expense-reports-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'medical_expense_reports_claim'
      end

      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        MedicalExpenseReports::SavedClaim
      end

      # GET serialized medical expense reports form data
      def show
        claim = claim_class.find_by!(guid: params[:id]) # raises ActiveRecord::RecordNotFound
        form_submission_attempt = last_form_submission_attempt(claim.guid)

        raise Common::Exceptions::RecordNotFound, params[:id] if form_submission_attempt.nil?

        pdf_url = s3_signed_url(claim, form_submission_attempt.created_at.to_date, config: MedicalExpenseReports::ZsfConfig.new)
        render json: ArchivedClaimSerializer.new(claim, params: { pdf_url: })
      rescue ActiveRecord::RecordNotFound => e
        monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        claim = claim_class.new(form: filtered_params[:form])
        monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          monitor.track_create_validation_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        process_attachments(in_progress_form, claim)

        MedicalExpenseReports::BenefitsIntake::SubmitClaimJob.perform_async(claim.id, current_user&.user_account_uuid)

        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)

        pdf_url = upload_to_s3(claim, config: MedicalExpenseReports::ZsfConfig.new)

        render json: ArchivedClaimSerializer.new(claim, params: { pdf_url: })
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      # Raises an exception if the medical expense reports flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:medical_expense_reports_form_enabled,
                                                                    current_user)
      end

      ##
      # Processes attachments for the claim
      #
      # @param in_progress_form [Object]
      # @param claim
      # @raise [Exception]
      def process_attachments(in_progress_form, claim)
        claim.process_attachments!
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      # Filters out the parameters to form access.
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      ##
      # include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [MedicalExpenseReports::SavedClaim]
      #
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [MedicalExpenseReports::Monitor]
      #
      def monitor
        @monitor ||= MedicalExpenseReports::Monitor.new
      end
    end
  end
end
