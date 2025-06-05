# frozen_string_literal: true

require 'kafka/concerns/kafka'
require 'pensions/benefits_intake/submit_claim_job'
require 'pensions/monitor'
require 'bpds/sidekiq/submit_to_bpds_job'

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
        process_and_upload_to_bpds(claim)

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

        Pensions::BenefitsIntake::SubmitClaimJob.perform_async(claim.id, current_user&.user_account_uuid)
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      # Processes the given claim and uploads it to the BPDS (Benefits Processing and Delivery System)
      # if the BPDS service feature is enabled via Flipper.
      #
      # @param claim [Claim] The saved claim object to be processed and uploaded.
      # @return [nil] Returns nil if the BPDS service feature is disabled.
      #
      # @note This method triggers a Sidekiq job to handle the submission asynchronously.
      def process_and_upload_to_bpds(claim)
        return nil unless Flipper.enabled?(:bpds_service_enabled)

        # Get an identifier associated with the user
        payload = get_user_identifier_for_bpds
        if payload.nil? || (payload[:participant_id].blank? && payload[:file_number].blank?)
          bpds_monitor.track_skip_bpds_job(claim.id)
          return
        end

        encrypted_payload = KmsEncrypted::Box.new.encrypt(payload.to_json)

        # Submit to BPDS
        bpds_monitor.track_submit_begun(claim.id)
        BPDS::Sidekiq::SubmitToBPDSJob.perform_async(claim.id, encrypted_payload)
      end

      # Retrieves an identifier for the current user for association with a BDPS submission.
      # The participant id or file number is sourced from MPI or BGS depending on the user's
      # LOA or if they are unauthenticated.
      #
      # @return [Hash, nil] Returns a hash containing the participant id or file number, or nil
      def get_user_identifier_for_bpds
        # user is LOA3 so we can use MPI service to get the user's MPI profile
        if current_user&.loa3?
          bpds_monitor.track_get_user_identifier('loa3')

          # Get profile participant_id from MPI service
          response = MPI::Service.new.find_profile_by_identifier(identifier: current_user.icn,
                                                                 identifier_type: MPI::Constants::ICN)
          participant_id = response.profile&.participant_id
          bpds_monitor.track_get_user_identifier_result('mpi', participant_id.present?)

          return { participant_id: }
        end

        # user is LOA1 so we need to use BGS
        if current_user&.loa&.dig(:current).try(:to_i) == LOA::ONE
          bpds_monitor.track_get_user_identifier('loa1')
          return get_participant_id_or_file_number_from_bgs
        end

        # user is unauthenticated so we need to use BGS
        bpds_monitor.track_get_user_identifier('unauthenticated')
        get_participant_id_or_file_number_from_bgs
      end

      # Retrieves an identifier of the current user for association with a BDPS submission.
      # This uses the BGS service to get the participant id or file number.
      #
      # @return [Hash, nil] Returns a hash containing the participant id or file number, or nil
      def get_participant_id_or_file_number_from_bgs
        return nil if current_user.nil?

        # Get profile participant_id from BGS service
        response = BGS::People::Request.new.find_person_by_participant_id(user: current_user)
        bpds_monitor.track_get_user_identifier_result('bgs', response.participant_id.present?)

        return { participant_id: response.participant_id } if response.participant_id.present?

        # Get file_number as participant_id is not present
        file_number = response.file_number
        bpds_monitor.track_get_user_identifier_file_number_result(file_number.present?)

        return { file_number: } if file_number.present?

        nil
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
      # retrieve a monitor for tracking
      #
      # @return [Pensions::Monitor]
      #
      def monitor
        @monitor ||= Pensions::Monitor.new
      end

      ##
      # retrieve a BPDS monitor for tracking
      #
      # @return [BPDS::Monitor]
      #
      def bpds_monitor
        @bpds_monitor ||= BPDS::Monitor.new
      end
    end
  end
end
