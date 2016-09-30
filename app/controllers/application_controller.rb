# frozen_string_literal: true
require 'common/exceptions'
require 'common/client/errors'

class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods
  before_action :authenticate
  before_action :set_app_info_headers
  skip_before_action :authenticate, only: [:cors_preflight]

  def cors_preflight
    head(:ok)
  end

  private

  rescue_from 'Exception' do |exception|
    log_error(exception)

    va_exception =
      case exception
      when ActionController::ParameterMissing
        Common::Exceptions::ParameterMissing.new(exception.param)
      when Common::Exceptions::BaseError
        exception
      when Common::Client::Errors::ClientResponse
        Common::Exceptions::ClientError.new(exception.message.capitalize)
      else
        Common::Exceptions::InternalServerError.new(exception)
      end

    render json: { errors: va_exception.errors }, status: va_exception.errors[0].status
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
      return false if @session.nil?
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
