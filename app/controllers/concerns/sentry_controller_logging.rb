# frozen_string_literal: true

module SentryControllerLogging
  extend ActiveSupport::Concern

  included { before_action :set_sentry_tags_and_extra_context }

  private

  def set_sentry_tags_and_extra_context
    Sentry.set_extras(request_uuid: request.uuid)
    Sentry.set_user(user_context) if current_user
    Sentry.set_tags(tags_context)
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
      # Add defensive checks to avoid nil errors
      sign_in = if current_user.respond_to(:identity) && current_user.identity&.sign_in.present?
                  current_user.identity.sign_in
                elsif current_user&.sign_in.present?
                  current_user.sign_in
                end

      if sign_in.present?
        tags[:sign_in_method] = sign_in[:service_name]
        # account_type is filtered by sentry, becasue in other contexts it refers to a bank account type
        tags[:sign_in_acct_type] = sign_in[:account_type]
      else
        tags[:sign_in_method] = 'not-signed-in'
      end
      tags[:source] = request.headers['Source-App-Name'] if request.headers['Source-App-Name']
    end
  end
end
