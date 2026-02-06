# frozen_string_literal: true

require 'income_and_assets/benefits_intake/submit_claim_job'
require 'income_and_assets/monitor'
require 'persistent_attachments/sanitizer'
require 'bpds/submission_handler'

module IncomeAndAssets
  module V0
    ###
    # The Income and Assets claim controller that handles form submissions
    #
    class ClaimsController < ClaimsBaseController
      include BPDS::SubmissionHandler

      before_action :check_flipper_flag
      service_tag 'income-and-assets-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'income_and_assets_claim'
      end

      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        IncomeAndAssets::SavedClaim
      end

      # GET serialized 0969 income and assets form data
      def show
        claim = claim_class.find_by!(guid: params[:id]) # raises ActiveRecord::RecordNotFound
        render json: SavedClaimSerializer.new(claim)
      rescue ActiveRecord::RecordNotFound => e
        monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        claim = create_claim(filtered_params[:form])
        monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          monitor.track_create_validation_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        # See BPDS::SubmissionHandler
        submit_claim_to_bpds(claim) if Flipper.enabled?(:income_and_assets_bpds_service_enabled)

        process_attachments(in_progress_form, claim)

        IncomeAndAssets::BenefitsIntake::SubmitClaimJob.perform_async(claim.id, current_user&.user_account_uuid)

        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      # Creates a new claim instance with the provided form parameters.
      #
      # @param form_params [String] The form data string for the claim.
      # @return [Claim] A new instance of the claim class initialized with the given attributes.
      #   If the current user has an associated user account, it is included in the claim attributes.
      def create_claim(form_params)
        claim_attributes = { form: form_params }
        claim_attributes[:user_account] = @current_user.user_account if @current_user&.user_account

        claim_class.new(**claim_attributes)
      end

      # Raises an exception if the income and assets flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:income_and_assets_form_enabled,
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
        sanitize_attachments(claim, in_progress_form)
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
      # @param claim [IncomeAndAssets::SavedClaim]
      #
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # Sanitizes attachments for a claim and handles persistent attachment errors.
      #
      # This method checks a feature flag to determine if
      # persistent attachment error handling should be enabled. If enabled, it:
      #   - Calls the PersistentAttachments::Sanitizer to remove bad attachments and update the in_progress_form.
      #   - Sends a persistent attachment error email notification if the claim supports it.
      #   - Destroys the claim if attachment processing fails.
      #
      # @param claim [IncomeAndAssets::SavedClaim] The claim whose attachments are being sanitized.
      # @param in_progress_form [InProgressForm] The in-progress form associated with the claim.
      # @return [void]
      def sanitize_attachments(claim, in_progress_form)
        feature_flag = Settings.vanotify.services['21p_0969'].email.persistent_attachment_error.flipper_id

        if Flipper.enabled?(feature_flag.to_sym)
          PersistentAttachments::Sanitizer.new.sanitize_attachments(claim, in_progress_form)
          claim.send_email(:persistent_attachment_error) if claim.respond_to?(:send_email)
          claim.destroy! # Handle deletion of the claim if attachments processing fails
        end
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [IncomeAndAssets::Monitor]
      #
      def monitor
        @monitor ||= IncomeAndAssets::Monitor.new
      end
    end
  end
end
