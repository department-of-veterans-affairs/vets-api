# frozen_string_literal: true

module OktaRedis
  class Profile < Model
    CLASS_NAME = 'ProfileService'
    def id
      okta_response.body['id']
    end

    private

    def okta_response
      do_cached_with(key: cache_key) do
        user_response = service.user(@user.uuid)
        if user_response.success?
          user_response
        else
          raise Common::Exceptions::RecordNotFound, @user.uuid
        end
      end
    end
  end
end
