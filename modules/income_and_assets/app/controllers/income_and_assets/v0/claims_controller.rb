# frozen_string_literal: true

require 'income_and_assets/claims/monitor'

module IncomeAndAssets
  module V0
    ###
    # The Income and Assets claim controller that handles form submissions
    #
    class ClaimsController < ClaimsBaseController
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
        ia_monitor.track_show404(params[:id], current_user&.user_account_uuid, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        ia_monitor.track_show_error(params[:id], current_user&.user_account_uuid, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        claim = claim_class.new(form: filtered_params[:form])
        ia_monitor.track_create_attempt(claim, current_user&.user_account_uuid)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        claim.upload_to_lighthouse(current_user)

        ia_monitor.track_create_success(in_progress_form&.id, claim, current_user&.user_account_uuid)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        ia_monitor.track_create_error(in_progress_form&.id, claim, current_user&.user_account_uuid, e)
        raise e
      end

      private

      # Raises an exception if the income and assets flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:pension_income_and_assets_clarification,
                                                                    current_user)
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
      # retreive a monitor for tracking
      #
      # @return [IncomeAndAssets::Claims::Monitor]
      #
      def ia_monitor
        @monitor ||= IncomeAndAssets::Claims::Monitor.new
      end
    end
  end
end
