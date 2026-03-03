# frozen_string_literal: true

require 'time_of_need/monitor'
require 'common/exceptions/validation_errors'

module TimeOfNeed
  module V0
    ##
    # Controller for Time of Need burial scheduling form submissions
    #
    # Handles form submissions from VA.gov, saves claims to the database,
    # and queues async jobs for submission to MuleSoft → MDW → CaMEO.
    #
    # Supports both authenticated and unauthenticated users.
    #
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :load_user, only: :create

      service_tag 'time-of-need'

      ##
      # GET /time_of_need/v0/claims/:id
      #
      # Retrieves a claim by GUID
      #
      # @return [JSON]
      def show
        claim = claim_class.find_by!(guid: params[:id])
        render json: SavedClaimSerializer.new(claim)
      rescue ActiveRecord::RecordNotFound => e
        monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      ##
      # POST /time_of_need/v0/claims
      #
      # Creates a new Time of Need claim from form data.
      # Saves claim to DB, processes attachments, and queues MuleSoft submission.
      #
      # @return [JSON]
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

        process_attachments(in_progress_form, claim)

        # Queue async MuleSoft submission (when implemented)
        # TimeOfNeed::MuleSoft::SubmitJob.perform_async(claim.id) if Flipper.enabled?(:time_of_need_mulesoft_enabled)

        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      ##
      # Creates a new claim instance with form params and optional user account
      #
      # @param form_params [Hash] The form data
      # @return [TimeOfNeed::SavedClaim]
      def create_claim(form_params)
        claim_attributes = { form: form_params }
        claim_attributes[:user_account] = @current_user.user_account if @current_user&.user_account

        claim_class.new(**claim_attributes)
      end

      ##
      # The parameter key for the form data in the JSON submission
      #
      # @return [String]
      def short_name
        'time_of_need_claim'
      end

      ##
      # The SavedClaim class for this module
      #
      # @return [Class]
      def claim_class
        TimeOfNeed::SavedClaim
      end

      ##
      # Processes file attachments for the claim
      #
      # @param in_progress_form [InProgressForm, nil]
      # @param claim [TimeOfNeed::SavedClaim]
      def process_attachments(in_progress_form, claim)
        claim.process_attachments!
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      ##
      # Filters and permits the form parameters
      #
      # @return [ActionController::Parameters]
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      ##
      # Include validation error on in_progress_form metadata
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [TimeOfNeed::SavedClaim]
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # Monitor instance for tracking
      #
      # @return [TimeOfNeed::Monitor]
      def monitor
        @monitor ||= TimeOfNeed::Monitor.new
      end
    end
  end
end
