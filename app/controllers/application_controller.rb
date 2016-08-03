class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_action :set_app_info_headers

  private

  def set_app_info_headers
    headers["X-GitHub-Repository"] = "https://github.com/department-of-veterans-affairs/vets-api"
    headers["X-Git-SHA"] = AppInfo::GIT_REVISION
  end

  def require_login
    redirect_to(root_path) && return if SAML::NO_LOGIN_MODE && !Rails.env.test?

    unless session[:user]
      flash[:after_login_controller] = request.parameters["controller"]
      flash[:after_login_action] = request.parameters["action"]
      redirect_to new_v0_sessions_path
    end
  end
end
