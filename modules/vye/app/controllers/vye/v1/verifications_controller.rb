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
        current_date = Time.zone.today
        final_award_end = pending_verifications.map { |pv| pv.act_end.to_date }.max

        if current_date >= final_award_end
          # If we're on or past the final award, return that final date
          pending_verifications.find { |pv| pv.act_end.to_date == final_award_end }&.act_end
        else
          # Otherwise, return either the max past date or end of previous month
          month_end = current_date.prev_month.end_of_month
          pending_verifications
            .map { |pv| pv.act_end.to_date }
            .select { |date| date < current_date }
            .max || month_end
        end
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
