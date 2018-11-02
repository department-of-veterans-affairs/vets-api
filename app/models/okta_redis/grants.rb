module OktaRedis
  class Grants < Model
    CLASS_NAME = "GrantsService"


    def okta_response
      do_cached_with(key: cache_key(@user.uuid)) do
        grants_response = service.grants(@user.okta_profile.id)
        grants_response.success? ? grants_response.body : []
      end
    end
    alias_method :all, :okta_response
  end
end