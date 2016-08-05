class ApplicationController < ActionController::API
  before_action :set_app_info_headers

  private

  def set_app_info_headers
    headers["X-GitHub-Repository"] = "https://github.com/department-of-veterans-affairs/vets-api"
    headers["X-Git-SHA"] = AppInfo::GIT_REVISION
  end

  def require_login
    redirect_to(root_path) && return if SAML::NO_LOGIN_MODE && !Rails.env.test?
    redirect_to new_v0_sessions_path unless session[:user]
  end
end
