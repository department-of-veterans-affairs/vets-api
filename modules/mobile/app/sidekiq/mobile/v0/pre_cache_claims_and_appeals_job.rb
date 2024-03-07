# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheClaimsAndAppealsJob
      include Sidekiq::Job

      sidekiq_options(retry: false)

      class MissingUserError < StandardError; end

      def perform(uuid)
        @user = IAMUser.find(uuid) || ::User.find(uuid)
        raise MissingUserError, uuid unless @user

        claims_index_interface.get_accessible_claims_appeals(false)
      rescue => e
        Rails.logger.warn('mobile claims pre-cache job failed',
                          user_uuid: uuid,
                          errors: e.message,
                          type: e.class.to_s)
      end

      private

      def claims_index_interface
        @claims_index_interface ||= Mobile::V0::LighthouseClaims::ClaimsIndexInterface.new(@user)
      end
    end
  end
end
