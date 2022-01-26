# frozen_string_literal: true

module OktaRedis
  class Profile < Model
    CLASS_NAME = 'ProfileService'
    def id
      okta_response['id']
    end

    private

    def okta_response
      do_cached_with(key: cache_key) do
        user_key = Settings.oidc.base_api_profile_key_icn ? @user.icn : @user.uuid
        if Settings.oidc.base_api_profile_key_icn
          raise Common::Exceptions::RecordNotFound, 'ICN' if user_key.nil?

          user_response = service.user_search_by_icn(user_key)
        else
          user_response = service.user(user_key)
        end

        if user_response.success?
          raise Common::Exceptions::RecordNotFound, user_key if user_response.body.length.zero?

          return Settings.oidc.base_api_profile_key_icn ? user_response.body[0] : user_response.body
        else
          raise Common::Exceptions::RecordNotFound, Settings.oidc.base_api_profile_key_icn ? 'ICN' : 'CSP ID'
        end
      end
    end
  end
end
