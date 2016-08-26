class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  before_action :authenticate
  before_action :set_app_info_headers
  skip_before_action :authenticate, only: [:cors_preflight]

  #TODO(shauni #45) - replace with rack-cors
  def cors_preflight
    head(:ok)
  end

  private

  def set_app_info_headers
    headers["X-GitHub-Repository"] = "https://github.com/department-of-veterans-affairs/vets-api"
    headers["X-Git-SHA"] = AppInfo::GIT_REVISION
  end

  def authenticate
    authenticate_token || render_unauthorized
  end

  def authenticate_token
    authenticate_with_http_token do |token, _options|
      @session = Session.find(token)
      # TODO: ensure that this prevents against timing attack vectors
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(token),
        ::Digest::SHA256.hexdigest(@session.token)
      )
      @current_user = User.find(@session.uuid)
    end
  end

  def render_unauthorized
    headers["WWW-Authenticate"] = 'Token realm="Application"'
    render json: "Not Authorized", status: 401
  end
end
