# frozen_string_literal: true

module Mobile
  module V0
    class PreCacheClaimsAndAppealsJob
      include Sidekiq::Worker

      sidekiq_options(retry: false)

      def perform(uuid)
        user = IAMUser.find(uuid)
        data, errors = claims_proxy(user).get_claims_and_appeals

        if errors.size.positive?
          Rails.logger.warn('mobile claims pre-cache set failed', user_uuid: uuid,
                                                                  errors: errors)
        else
          Mobile::V0::ClaimOverview.set_cached(user.uuid, data)
          Rails.logger.info('mobile claims pre-cache set succeeded', user_uuid: uuid)
        end
      end

      private

      def claims_proxy(user)
        Mobile::V0::Claims::Proxy.new(user)
      end
    end
  end
end
