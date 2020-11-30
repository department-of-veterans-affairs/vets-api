# frozen_string_literal: true

# We need to ensure that the response class is defined before we ask Common::RedisStore.find to
# deserialize one.
require_dependency 'okta/response'

module OktaRedis
  class Grants < Model
    CLASS_NAME = 'GrantsService'

    after_initialize do |grants|
      grants.instance_variable_set(:@activity_log, [])
    end

    def all
      all_grants = okta_response.body
      log_message_to_sentry('Getting all grants', :info,
                            grants_service_activity: @activity_log)
      all_grants
    end

    def delete_grants(grant_ids)
      success = grant_ids.reduce(true) { |memo, grant| delete_grant(grant) && memo }
      OktaRedis::Grants.delete(cache_key) if success
      log_message_to_sentry('Deleting all grants', :info,
                            grants_service_activity: @activity_log)
      success
    end

    def delete_grant(grant_id)
      delete_response = service.delete_grant(@user.okta_profile.id, grant_id)
      @activity_log << "Deleting grant id #{grant_id}.  Success? #{delete_response.success?}"
      if delete_response.success?
        true
      else
        log_message_to_sentry("Error deleting grant #{grant_id}", :error,
                              {
                                body: delete_response.body,
                                grants_service_activity: @activity_log
                              })
        raise 'Unable to delete grant'
      end
    end

    private

    def okta_response
      @activity_log << 'Get okta response including grants'
      response = do_cached_with(key: cache_key) do
        @activity_log << 'Fetch new response'
        grants_response = service.grants(@user.okta_profile.id)
        grants_response.success? ? grants_response : []
      end
      @activity_log << "Retrieved #{response.body.count} grants"
      response
    end
  end
end
