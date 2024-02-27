# frozen_string_literal: true

require_relative '../../../services/mobile/v0/lighthouse_claims/service_authorization_interface'

module Mobile
  module V0
    class PreCacheClaimsAndAppealsJob
      include Sidekiq::Job
      include Pundit::Authorization

      sidekiq_options(retry: false)

      class MissingUserError < StandardError; end

      def perform(uuid)
        @user = IAMUser.find(uuid) || ::User.find(uuid)
        raise MissingUserError, uuid unless @user

        data, errors = service_authorization_interface(@user).get_accessible_claims_appeals(false)

        if service_authorization_interface(@user).non_authorization_errors?(errors)
          Rails.logger.warn('mobile claims pre-cache fetch errors', user_uuid: uuid,
                                                                    errors:)
        else
          Mobile::V0::ClaimOverview.set_cached(@user, data)
        end
      rescue => e
        Rails.logger.warn('mobile claims pre-cache job failed',
                          user_uuid: uuid,
                          errors: e.message,
                          type: e.class.to_s)
      end

      private

      def service_authorization_interface(user)
        @appointments_cache_interface ||= Mobile::ServiceAuthorizationInterface.new(user)
      end
    end
  end
end
