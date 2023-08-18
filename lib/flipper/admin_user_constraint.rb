# frozen_string_literal: true

module Flipper
  class AdminUserConstraint
    def self.matches?(request)
      # Confirm that requests to toggle (POST to /boolean) are authorized
      url_pattern = %r{\A/flipper/features/[^/]+/boolean\z}
      if request.method == 'POST' && request.path.match?(url_pattern)
        return true if authorized?(request.session[:flipper_user])

        raise Common::Exceptions::Forbidden
      end

      # If Authenticated through GitHub, check authorization to determine what can be shown in views
      if request.session[:flipper_user].present?
        user = request.session[:flipper_user]
        RequestStore.store[:flipper_user_email_for_log] =
          user&.email || "Email not found for: #{user&.name || '<no name>'}, #{user&.company || '<no company>'}"
        RequestStore.store[:flipper_authorized] = authorized?(user)

        return true
      end

      # allow GET requests (minus the callback, which needs to pass through to finish auth flow)
      return true if (request.method == 'GET' && request.path.exclude?('/callback')) || Rails.env.development?

      authenticate(request)
      true
    end

    def self.authenticate(request)
      RequestStore.store[:flipper_user_email_for_log] = nil
      warden = request.env['warden']
      warden.authenticate!(scope: :flipper)
    end

    def self.authorized?(user)
      return true if Rails.env.development?

      org_name = Settings.flipper.github_organization
      team_id = Settings.flipper.github_team

      user&.organization_member?(org_name) && user&.team_member?(team_id)
    end
  end
end
