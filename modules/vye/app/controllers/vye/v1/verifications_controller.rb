# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      class EmptyAwards < StandardError; end
      class AwardsMismatch < StandardError; end

      rescue_from EmptyAwards, with: -> { head :unprocessable_entity }
      rescue_from AwardsMismatch, with: -> { head :unprocessable_entity }

      # this is in the models concern NeedsEnrollmentVerification and is aliased to enrollments
      delegate :pending_verifications, to: :user_info

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
