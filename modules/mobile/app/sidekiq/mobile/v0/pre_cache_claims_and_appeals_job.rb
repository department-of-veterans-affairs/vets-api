# frozen_string_literal: true

require 'modules/mobile/app/services/mobile/v0/lighthouse_claims/claims_index_interface'

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

        data, errors = claims_index_interface(@user).get_accessible_claims_appeals(false)

        claims_index_interface(@user).try_cache(data, errors)
      rescue => e
        Rails.logger.warn('mobile claims pre-cache job failed',
                          user_uuid: uuid,
                          errors: e.message,
                          type: e.class.to_s)
      end

      private

      def claims_index_interface(user)
        @claims_index_interface ||= Mobile::ClaimsIndexInterface.new(user)
      end
    end
  end
end
