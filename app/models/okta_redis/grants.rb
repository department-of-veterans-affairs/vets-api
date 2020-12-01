# frozen_string_literal: true

# We need to ensure that the response class is defined before we ask Common::RedisStore.find to
# deserialize one.
require_dependency 'okta/response'

module OktaRedis
  class Grants < Model
    CLASS_NAME = 'GrantsService'

    def all
      okta_response.body
    end

    def delete_grants(grant_ids)
      success = grant_ids.reduce(true) { |memo, grant| delete_grant(grant) && memo }
      OktaRedis::Grants.delete(cache_key) if success
      success
    end

    def delete_grant(grant_id)
      delete_response = service.delete_grant(@user.okta_profile.id, grant_id)
      if delete_response.success?
        true
      else
        log_message_to_sentry("Error deleting grant #{grant_id}", :error,
                              body: delete_response.body)
        raise 'Unable to delete grant'
      end
    end

    private

    def okta_response
      do_cached_with(key: cache_key) do
        grants_response = service.grants(@user.okta_profile.id)
        grants_response.success? ? grants_response : []
      end
    end
  end
end
