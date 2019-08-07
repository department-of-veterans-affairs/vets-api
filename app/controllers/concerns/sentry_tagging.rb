# frozen_string_literal: true

##
# Represents logic and defines methods for tagging with Sentry/Raven
module SentryTagging
  extend ActiveSupport::Concern

  included do
    before_action :set_tags_and_extra_context
  end

  private

  def set_tags_and_extra_context
    Thread.current['request_id'] = request.uuid
    Thread.current['additional_request_attributes'] = {
      'request_ip' => request.remote_ip,
      'request_agent' => request.user_agent
    }

    Raven.extra_context(extra_context)
    Raven.user_context(user_context) if current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      uuid: current_user&.uuid,
      authn_context: current_user&.authn_context,
      loa: current_user&.loa,
      mhv_icn: current_user&.mhv_icn
    }
  end

  def tags_context
    {
      controller_name: controller_name,
      sign_in_method: sign_in_method_for_tag
    }
  end

  def extra_context
    {
      request_uuid: request.uuid
    }
  end

  def sign_in_method_for_tag
    if current_user.present?
      # account_type is filtered by sentry, becasue in other contexts it refers to a bank account type
      current_user.identity.sign_in.merge(acct_type: current_user.identity.sign_in[:account_type])
    else
      'not-signed-in'
    end
  end
end
