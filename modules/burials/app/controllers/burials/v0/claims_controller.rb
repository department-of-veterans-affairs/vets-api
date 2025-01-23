# frozen_string_literal: true

require 'pension_burial/tag_sentry'
require 'common/exceptions/validation_errors'

module Burials
  module V0
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :load_user, only: :create

      service_tag 'burial-application'

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

      def create
        PensionBurial::TagSentry.tag_sentry

        claim = claim_class.new(form: filtered_params[:form])
        monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
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

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'burial_claim'
      end

      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        Burials::SavedClaim
      end

      def process_and_upload_to_lighthouse(in_progress_form, claim)
        claim.process_attachments!

        Lighthouse::SubmitBenefitsIntakeClaim.perform_async(claim.id)
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
      # @param claim [Pensions::SavedClaim]
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
      # @return [Burials::Monitor]
      #
      def monitor
        @monitor ||= Burials::Monitor.new
      end
    end
  end
end
