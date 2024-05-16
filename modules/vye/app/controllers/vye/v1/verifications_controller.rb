# frozen_string_literal: true

module Vye
  module Vye::V1
    class Vye::V1::VerificationsController < Vye::V1::ApplicationController
      class EmptyAwards < StandardError; end
      class AwardsMismatch < StandardError; end

      include Pundit::Authorization
      include Vye::Ivr

      service_tag 'verify-your-enrollment'

      rescue_from EmptyAwards, with: -> { head :unprocessable_entity }
      rescue_from AwardsMismatch, with: -> { head :unprocessable_entity }

      delegate :pending_verifications, to: :user_info

      def create
        authorize user_info, policy_class: UserInfoPolicy

        validate_award_ids!

        transact_date = Time.zone.today
        pending_verifications.each do |verification|
          verification.update!(transact_date:, source_ind:)
        end

        head :no_content
      end

      private

      def award_ids
        transformed_params.fetch(:award_ids, []).map(&:to_i)
      end

      def matching_awards?
        given = award_ids.sort
        actual = pending_verifications.pluck(:award_id).sort
        given == actual
      end

      def validate_award_ids!
        raise EmptyAwards if award_ids.blank?
        raise AwardsMismatch unless matching_awards?
      end

      def source_ind
        api_key? ? :phone : :web
      end

      def load_user_info(scoped: Vye::UserProfile)
        return super(scoped:) unless api_key?

        @user_info = user_info_for_ivr(scoped:)
      end

      protected

      def transformed_params
        @transform_params ||= params.deep_transform_keys!(&:underscore)
      end
    end
  end
end
