# frozen_string_literal: true

require 'dgib/verification_record/service'

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      class EmptyAwards < StandardError; end
      class AwardsMismatch < StandardError; end

      rescue_from EmptyAwards, with: -> { head :unprocessable_entity }
      rescue_from AwardsMismatch, with: -> { head :unprocessable_entity }

      # this is in the models concern NeedsEnrollmentVerification and is aliased to enrollments
      delegate :pending_verifications, to: :user_info

      def get_verification_record
        response = verification_service.get_verification_record(params[:claimant_id])
        serializer = Vye::ClaimantVerificationSerializer
        process_response(response.status, serializer)
      end

      def verify_claimant
        response =
          verify_claimant_service
          .verify_claimant(
            params[:claimant_id],
            params[:verified_period_begin_date],
            params[:verified_period_end_date],
            params[:verfied_through_date]
          )

        serializer = Vye::VerifyClaimantSerializer
        process_response(response.status, serializer)
      end

      # the serializer for this endpoint is the same as for verify_claimant
      def get_claimant_status
        response = claimant_status_service.get_claimant_status(params[:claimant_id])
        serializer = Vye::VerifyClaimantSerializer
        process_response(response.status, serializer)
      end

      def claimant_lookup
        Logger.info("\n\n\n*** Claimant Lookup ***")
        Logger.info("*** SSN: #{params[:ssn]} ***\n\n\n")
        response = claimant_lookup_service.claimant_lookup(params[:ssn])
        serializer = Vye::ClaimantLookupSerializer
        process_response(response.status, serializer)
      end

      def create
        authorize user_info, policy_class: UserInfoPolicy

        validate_award_ids!

        transact_date = cert_through_date
        pending_verifications.each do |verification|
          verification.update!(transact_date:, source_ind:)
        end

        head :no_content
      end

      private

      # Vye Services related stuff
      def claimant_lookup_service
        Vye::DGIB::ClaimantLookupService.new(@current_user)
      end

      def claimant_status_service
        Vye::DGIB::ClaimantStatusService.new(@current_user)
      end

      def verification_service
        Vye::DGIB::VerificationRecord::Service.new(@current_user)
      end

      def verify_claimant_service
        Vye::DGIB::VerifyClaimantService.new(@current_user)
      end

      def process_response(response_status, serializer)
        case response_status
        when 200
          render json: serializer.new(response)
        when 204
          head :no_content
        when 403
          head :forbidden
        when 404
          head :not_found
        when 422
          head :unprocessable_entity
        when 500
          head :internal_server_error
        else
          head :server_error
        end
      end
      # End Vye Services

      def cert_through_date
        # act_end is defined as timestamp without time zone
        found = Time.new(1970, 1, 1, 0, 0, 0, 0) # '1970-01-01 00:00:00'

        pending_verifications.each { |pv| found = pv.act_end if pv.act_end > found }

        return nil if found.eql?(Time.new(1970, 1, 1, 0, 0, 0, 0))

        found
      end

      def award_ids
        params.fetch(:award_ids, []).map(&:to_i)
      end

      def matching_awards?
        given = award_ids.sort
        actual = pending_verifications.pluck(:award_id).uniq.sort
        given == actual
      end

      def validate_award_ids!
        raise EmptyAwards if award_ids.blank?
        raise AwardsMismatch unless matching_awards?
      end

      def source_ind = :web
    end
  end
end
