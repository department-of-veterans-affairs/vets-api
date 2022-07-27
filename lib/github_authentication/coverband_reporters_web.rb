# frozen_string_literal: true

module GithubAuthentication
  class CoverbandReportersWeb
    def matches?(request)
      return true if Settings.vsp_environment == 'development'

      warden = request.env['warden']
      request.session[:coverband_user] ||= warden.user

      if request.session[:coverband_user].blank?
        warden.authenticate!(scope: :coverband)
        request.session[:coverband_user] = warden.user
      end

      if github_organization_authenticate!(request.session[:coverband_user], Settings.coverband.github_organization,
                                           Settings.coverband.github_team)
        return true
      end

      false
    end

    private

    def github_organization_authenticate!(user, organization, team)
      user.organization_member?(organization) &&
        user.team_member?(team)
    end
  end
end
