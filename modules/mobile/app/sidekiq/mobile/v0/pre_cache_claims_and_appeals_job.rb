# frozen_string_literal: true

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

        data, errors = get_accessible_claims_appeals

        if non_authorization_errors?(errors)
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

      def get_accessible_claims_appeals
        if claims_access? && appeals_access?
          service.get_claims_and_appeals(false)
        elsif claims_access?
          service.get_claims(false)
        elsif appeals_access?
          service.get_appeals(false)
        else
          raise Pundit::NotAuthorizedError
        end
      end

      def claims_access?
        if claim_status_lighthouse?
          @user.authorize(:lighthouse,
                          :access?)
        else
          @user.authorize(:evss, :access?)
        end
      end

      def appeals_access?
        @user.authorize(:appeals, :access?)
      end

      def claim_status_lighthouse?
        Flipper.enabled?(:mobile_lighthouse_claims, @user)
      end

      def service
        if claim_status_lighthouse?
          Mobile::V0::LighthouseClaims::Proxy.new(@user)
        else
          Mobile::V0::Claims::Proxy.new(@user)
        end
      end

      def non_authorization_errors?(service_errors)
        return false unless service_errors

        authorization_errors = [Mobile::V0::Claims::Proxy::CLAIMS_NOT_AUTHORIZED_MESSAGE,
                                Mobile::V0::Claims::Proxy::APPEALS_NOT_AUTHORIZED_MESSAGE]
        !service_errors.all? { |error| authorization_errors.include?(error[:error_details]) }
      end
    end
  end
end
