# frozen_string_literal: true

require 'feature_flipper'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include AuthenticationAndSSOConcerns
  include ActionController::RequestForgeryProtection
  include ExceptionHandling
  include Headers
  include Instrumentation
  include Pundit::Authorization
  include SentryLogging
  include SentryControllerLogging

  protect_from_forgery with: :exception, if: -> { ActionController::Base.allow_forgery_protection }
  after_action :set_csrf_header, if: -> { ActionController::Base.allow_forgery_protection }

  # also see AuthenticationAndSSOConcerns, Headers, and SentryControllerLogging
  # for more before filters
  skip_before_action :authenticate, only: %i[cors_preflight routing_error]
  skip_before_action :verify_authenticity_token, only: :routing_error

  VERSION_STATUS = {
    draft: 'Draft Version',
    current: 'Current Version',
    previous: 'Previous Version',
    deprecated: 'Deprecated Version'
  }.freeze

  def cors_preflight
    head(:ok)
  end

  def routing_error
    raise Common::Exceptions::RoutingError, params[:path]
  end

  def clear_saved_form(form_id)
    InProgressForm.form_for_user(form_id, current_user)&.destroy if current_user
  end

  private

  attr_reader :current_user

  def set_csrf_header
    token = form_authenticity_token
    response.set_header('X-CSRF-Token', token)
  end

  def pagination_params
    {
      page: params[:page],
      per_page: params[:per_page]
    }
  end

  def render_job_id(jid)
    render json: { job_id: jid }, status: :accepted
  end
end
