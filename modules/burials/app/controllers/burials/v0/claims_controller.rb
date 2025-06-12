# frozen_string_literal: true

require 'burials/benefits_intake/submit_claim_job'
require 'burials/monitor'
require 'common/exceptions/validation_errors'

module Burials
  module V0
    ###
    # The Burial claim controller that handles form submissions
    #
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :load_user, only: :create

      service_tag 'burial-application'

      #
      # Retrieves a claim by its GUID and returns it as a serialized JSON response
      #
      # @return [JSON]
      # @raise [ActiveRecord::RecordNotFound]
      # @raise [Exception]
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
      # Creates a new claim instance, serializes it, and returns the result as JSON
      #
      # The `create` method initializes a new `SavedClaim` object using the
      # form data passed in via vets-website API endpoint
      #
      # @return [JSON]
      # @raise [Exception]
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

        process_and_upload_to_lighthouse(in_progress_form, claim)

        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      ##
      # An identifier that matches the parameter that the form will be set as in the JSON submission
      #
      # @return  [String]
      def short_name
        'burial_claim'
      end

      ##
      # Returns the class used for claims within the Burials module
      # A subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      #
      # @return [Burials::SavedClaim]
      def claim_class
        Burials::SavedClaim
      end

      ##
      # Processes attachments for the claim and initiates an async task for intake processing
      #
      # @param in_progress_form [Object]
      # @param claim
      # @raise [Exception]
      def process_and_upload_to_lighthouse(in_progress_form, claim)
        claim.process_attachments!

        Burials::BenefitsIntake::SubmitClaimJob.perform_async(claim.id)
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      ##
      # Filters and permits the form parameters required for processing
      #
      # @return [ActionController::Parameters]
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      ##
      # Include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [Burials::SavedClaim]
      #
      # @return [void]
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [Burials::Monitor]
      def monitor
        @monitor ||= Burials::Monitor.new
      end
    end
  end
end
