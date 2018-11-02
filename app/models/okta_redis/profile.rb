module OktaRedis
  class Profile < Model
    CLASS_NAME = "ProfileService"
    def id
      binding.pry
      okta_response['id']
    end

    private

    def okta_response
      do_cached_with(key: cache_key(@user.uuid)) do
        user_response = service.user(@user.uuid)
        if user_response.success?
          user_response.body
        else
          raise Common::Exception::RecordNotFound, @user.uuid
        end
      end
    end
  end
end