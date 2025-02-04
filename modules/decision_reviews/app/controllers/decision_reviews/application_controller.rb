# frozen_string_literal: true

require 'feature_flipper'
require 'aes_256_cbc_encryptor'

module DecisionReviews
  class ApplicationController < ActionController::API
    include AuthenticationAndSSOConcerns
    include ActionController::RequestForgeryProtection
    include ExceptionHandling
    include Headers
    include Pundit::Authorization
    include Traceable

    protect_from_forgery with: :exception, if: -> { ActionController::Base.allow_forgery_protection }
    after_action :set_csrf_header, if: -> { ActionController::Base.allow_forgery_protection }
    before_action :set_tags

    private

    attr_reader :current_user

    def set_tags
      RequestStore.store['request_id'] = request.uuid
      RequestStore.store['additional_request_attributes'] = {
        'remote_ip' => request.remote_ip,
        'user_agent' => request.user_agent,
        'user_uuid' => current_user&.uuid,
        'source' => request.headers['Source-App-Name']
      }
    end

    def set_csrf_header
      token = form_authenticity_token
      response.set_header('X-CSRF-Token', token)
    end

    def log_exception(exception, _extra_context = {}, _tags_context = {}, level = 'error')
      level = normalize_level(level, exception)

      if exception.is_a? Common::Exceptions::BackendServiceException
        rails_logger(level, exception.message, exception.errors, exception.backtrace)
      else
        rails_logger(level, "#{exception.message}.")
      end
      rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
    end

    alias log_exception_to_sentry log_exception # Method call in shared ExceptionHandling is :log_exception_to_sentry

    def normalize_level(level, exception)
      # https://docs.sentry.io/platforms/ruby/usage/set-level/
      # valid sentry levels: log, debug, info, warning, error, fatal

      level = case exception
              when Pundit::NotAuthorizedError
                'info'
              when Common::Exceptions::BaseError
                exception.sentry_type.to_s
              else
                level.to_s
              end

      return 'warning' if level == 'warn'

      level
    end

    def rails_logger(level, message, errors = nil, backtrace = nil)
      # rails logger uses 'warn' instead of 'warning'
      level = 'warn' if level == 'warning'
      if errors.present?
        error_details = errors.first.attributes.compact.reject { |_k, v| v.try(:empty?) }
        Rails.logger.send(level, message, error_details.merge(backtrace:))
      else
        Rails.logger.send(level, message)
      end
    end
  end
end
