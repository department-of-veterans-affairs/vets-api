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

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    authenticate_or_request_with_http_token do |token, options|
      session = Session.find(token)
      # TODO: ensure that this prevents against timing attack vectors
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(session.token)
      )
      @current_user = User.find(session.uuid)
    end
  end

  def render_unauthorized
    self.headers['WWW-Authenticate'] = 'Token realm="Application"'
    render json: 'Not Authorized', status: 401
  end
end
