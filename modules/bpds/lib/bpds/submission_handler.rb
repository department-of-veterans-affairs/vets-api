# frozen_string_literal: true

require 'bpds/monitor'
require 'bpds/sidekiq/submit_to_bpds_job'

module BPDS
  ##
  # Provides BPDS integration for claim submissions.
  #
  # This concern handles:
  # - User identifier lookup (participant_id or file_number) via MPI or BGS
  # - Encrypted payload creation for BPDS submissions
  # - Asynchronous job queueing for BPDS processing
  # - Comprehensive monitoring and logging of the submission process
  #
  # @example Include in a controller
  #   class MyClaimsController < ApplicationController
  #     include BPDS::SubmissionHandler
  #
  #     def create
  #       claim = create_claim(params)
  #       submit_claim_to_bpds(claim) if claim.save
  #     end
  #   end
  #
  module SubmissionHandler
    extend ActiveSupport::Concern

    ##
    # Submits a claim to BPDS if the feature flag is enabled and user identifiers are available.
    #
    # This method:
    # 1. Checks if BPDS submission is enabled via feature flag
    # 2. Retrieves user identifier (participant_id or file_number)
    # 3. Encrypts the payload for secure transmission
    # 4. Queues the BPDS submission job
    #
    # @param claim [SavedClaim] The saved claim to submit to BPDS
    # @return [Boolean] true if submission was queued, false otherwise
    def submit_claim_to_bpds(claim)
      return false unless Flipper.enabled?(:bpds_service_enabled)

      payload = retrieve_user_identifier_for_bpds

      if payload.nil? || (payload[:participant_id].blank? && payload[:file_number].blank?)
        bpds_monitor.track_skip_bpds_job(claim.id)
        return false
      end

      encrypted_payload = KmsEncrypted::Box.new.encrypt(payload.to_json)
      bpds_monitor.track_submit_begun(claim.id)
      BPDS::Sidekiq::SubmitToBPDSJob.perform_async(claim.id, encrypted_payload)

      true
    end

    private

    ##
    # Retrieves user identifier (participant_id or file_number) for BPDS submission.
    #
    # The lookup strategy depends on user authentication level:
    # - LOA3: Uses MPI service to retrieve participant_id from user profile
    # - LOA1: Uses BGS service to retrieve participant_id or file_number
    # - Unauthenticated: Uses BGS service with form data to retrieve identifiers
    #
    # @return [Hash, nil] Hash with :participant_id or :file_number key, or nil if not found
    #
    def retrieve_user_identifier_for_bpds
      if current_user&.loa3?
        retrieve_identifier_from_mpi
      elsif current_user&.loa&.dig(:current).try(:to_i) == LOA::ONE
        bpds_monitor.track_get_user_identifier('loa1')
        retrieve_identifier_from_bgs
      else
        bpds_monitor.track_get_user_identifier('unauthenticated')
        retrieve_identifier_from_bgs
      end
    end

    ##
    # Retrieves participant_id from MPI service for LOA3 users.
    #
    # @return [Hash, nil] Hash with :participant_id key or nil
    #
    def retrieve_identifier_from_mpi
      bpds_monitor.track_get_user_identifier('loa3')

      response = MPI::Service.new.find_profile_by_identifier(
        identifier: current_user.icn,
        identifier_type: MPI::Constants::ICN
      )

      participant_id = response.profile&.participant_id
      bpds_monitor.track_get_user_identifier_result('mpi', participant_id.present?)

      participant_id.present? ? { participant_id: } : nil
    end

    ##
    # Retrieves participant_id or file_number from BGS service.
    #
    # Priority order:
    # 1. participant_id (if present)
    # 2. file_number (if participant_id not present)
    #
    # @return [Hash, nil] Hash with :participant_id or :file_number key, or nil if not found
    #
    def retrieve_identifier_from_bgs
      return nil if current_user.nil?

      response = BGS::People::Request.new.find_person_by_participant_id(user: current_user)
      bpds_monitor.track_get_user_identifier_result('bgs', response.participant_id.present?)

      return { participant_id: response.participant_id } if response.participant_id.present?

      file_number = response.file_number
      bpds_monitor.track_get_user_identifier_file_number_result(file_number.present?)

      file_number.present? ? { file_number: } : nil
    end

    ##
    # Returns a memoized BPDS::Monitor instance for tracking submission events.
    #
    # @return [BPDS::Monitor]
    #
    def bpds_monitor
      @bpds_monitor ||= BPDS::Monitor.new
    end
  end
end
