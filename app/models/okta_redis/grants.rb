# frozen_string_literal: true

module OktaRedis
  class Grants < Model
    CLASS_NAME = 'GrantsService'

    def all
      @all_grants ||= service.grants(@user.okta_profile.id).body
    end

    def delete_grants(grant_ids)
      grant_ids.map { |grant| delete_grant(grant) }
    end

    def delete_grant(grant_id)
      delete_response = service.delete_grant(@user.okta_profile.id, grant_id)
      unless delete_response.success?
        log_message_to_sentry("Error deleting grant #{grant_id}", :error,
                              body: delete_response.body)
        raise 'Unable to delete grant'
      end
      delete_response
    end
  end
end
