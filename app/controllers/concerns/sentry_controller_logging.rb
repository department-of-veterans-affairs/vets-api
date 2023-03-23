# frozen_string_literal: true

module SentryControllerLogging
  extend ActiveSupport::Concern

  included { before_action :set_tags_and_extra_context }

  private

  def set_tags_and_extra_context
    RequestStore.store['request_id'] = request.uuid
    RequestStore.store['additional_request_attributes'] = {
      'remote_ip' => request.remote_ip,
      'user_agent' => request.user_agent,
      'user_uuid' => current_user&.uuid,
      'source' => request.headers['Source-App-Name']
    }
    Raven.extra_context(request_uuid: request.uuid)
    Raven.user_context(user_context) if current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      id: current_user&.uuid,
      authn_context: current_user&.authn_context,
      loa: current_user&.loa,
      mhv_icn: current_user&.mhv_icn
    }
  end

  def tags_context
    { controller_name: }.tap do |tags|
      if current_user.present?
        tags[:sign_in_method] = current_user.identity.sign_in[:service_name]
        # account_type is filtered by sentry, becasue in other contexts it refers to a bank account type
        tags[:sign_in_acct_type] = current_user.identity.sign_in[:account_type]
      else
        tags[:sign_in_method] = 'not-signed-in'
      end
      tags[:source] = request.headers['Source-App-Name'] if request.headers['Source-App-Name']
    end
  end
end
