class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  before_filter :set_app_info_headers

  def set_app_info_headers
  	headers['X-GitSHA'] = AppInfo::GIT_REVISION
  end
end
