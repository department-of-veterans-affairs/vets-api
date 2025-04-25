# frozen_string_literal: true

require 'kafka/concerns/kafka'
require 'pensions/benefits_intake/pension_benefit_intake_job'
require 'pensions/monitor'

module Pensions
  module V0
    ##
    # The pensions claim controller that handles form submissions
    #
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :load_user, only: :create

      service_tag 'pension-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'pension_claim'
      end

      ##
      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      #
      def claim_class
        Pensions::SavedClaim
      end

      ##
      # GET serialized pension form data
      #
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
        claim = claim_class.new(form: filtered_params[:form])
        monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          monitor.track_create_validation_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        submit_traceability_to_event_bus(claim) if Flipper.enabled?(:pension_kafka_event_bus_submission_enabled)

        # Submit to BPDS if the feature is enabled
        process_and_upload_to_bpds(claim) if Flipper.enabled?(:bpds_service_enabled)

        process_and_upload_to_lighthouse(in_progress_form, claim)

        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      # Build payload and submit to EventBusSubmissionJob
      #
      # @param claim [Pensions::SavedClaim]
      def submit_traceability_to_event_bus(claim)
        Kafka.submit_event(
          icn: current_user&.icn.to_s,
          current_id: claim&.confirmation_number.to_s,
          submission_name: Pensions::FORM_ID,
          state: Kafka::State::RECEIVED
        )
      end

      # link the form to the uploaded attachments and perform submission job
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [Pensions::SavedClaim]
      def process_and_upload_to_lighthouse(in_progress_form, claim)
        claim.process_attachments!

        Pensions::PensionBenefitIntakeJob.perform_async(claim.id, current_user&.user_account_uuid)
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      def process_and_upload_to_bpds(in_progress_form, claim)
        # Submit to BPDS
        BPDS::Monitor.new.track_submit_begun(claim.id)
        bpds_submission = BPDS::Submission.create(
          saved_claim: claim,
          form_id: claim.form_id,
          reference_data: claim.form
        )
        BPDS::SubmitToBPDSJob.perform_async(bpds_submission.id)
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      # Filters out the parameters to form access.
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      # include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [Pensions::SavedClaim]
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [Pensions::Monitor]
      #
      def monitor
        @monitor ||= Pensions::Monitor.new
      end
    end
  end
end
