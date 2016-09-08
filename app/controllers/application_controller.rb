# frozen_string_literal: true
require 'va/api/common/exceptions'
class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  before_action :authenticate
  before_action :set_app_info_headers
  skip_before_action :authenticate, only: [:cors_preflight]

  # TODO(shauni #45) - replace with rack-cors
  def cors_preflight
    head(:ok)
  end

  private

  rescue_from 'Exception' do |exception|
    log_error(exception)
    case exception
    when VA::API::Common::Exceptions::BaseError
      render json: { errors: exception.errors }
    else
      render json: { errors: VA::API::Common::Exceptions::InternalServerError.new(exception).errors }
      # FIXME: do we need to re-raise the exception as long as we are logging it and rendering something?
      # Maybe we will need a new relic specific method to call here??
      # raise exception if Rails.env.production?
    end
  end

  def log_error(exception)
    Rails.logger.error "#{exception.message}."
    Rails.logger.error exception.backtrace.join("\n") unless exception.backtrace.nil?
  end

  def set_app_info_headers
    headers['X-GitHub-Repository'] = 'https://github.com/department-of-veterans-affairs/vets-api'
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
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
    headers['WWW-Authenticate'] = 'Token realm="Application"'
    render json: 'Not Authorized', status: 401
  end
end
