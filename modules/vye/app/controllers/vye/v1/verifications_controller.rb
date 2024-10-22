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

      def get_verification_record(claimant_id)
        response = verification_service.get_verification_record(claimant_id)
        serializer = Vye::ClaimantVerificationSerializer

        case response.status
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

      def verification_service
        Vye::DGIB::VerificationRecord::Service.new(@current_user)
      end

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
