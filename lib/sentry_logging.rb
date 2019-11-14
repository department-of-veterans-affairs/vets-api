# frozen_string_literal: true

module SentryLogging
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def log_error(error)
    if Raven::Configuration::IGNORE_DEFAULT.include?(error.class)
      rails_logger(error.message.to_s, backtrace: error.backtrace)
    else
      extra = error.respond_to?(:errors) ? { errors: error.errors.map(&:to_hash) } : {}
      if error.is_a?(Common::Exceptions::BackendServiceException)
        # Add additional user specific context to the logs
        if @current_user.present?
          extra[:icn] = @current_user.icn
          extra[:mhv_correlation_id] = @current_user.mhv_correlation_id
        end
        # Warn about VA900 needing to be added to exception.en.yml
        log_message_to_sentry(error.va900_warning, :warn, i18n_exception_hint: error.va900_hint) if error.generic_error?
      end
      unless Raven::Configuration::IGNORE_DEFAULT.include?(error.class)
        log_exception_to_sentry(error, va_exception_errors: error.errors.map(&:to_hash))
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def set_tags_and_extra_context
    Thread.current['request_id'] = request.uuid
    Thread.current['additional_request_attributes'] = {
      'remote_ip' => request.remote_ip,
      'user_agent' => request.user_agent
    }
    Raven.extra_context(request_uuid: request.uuid)
    Raven.user_context(user_context) if current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      uuid: current_user&.uuid,
      authn_context: current_user&.authn_context,
      loa: current_user&.loa,
      mhv_icn: current_user&.mhv_icn
    }
  end

  def tags_context
    { controller_name: controller_name }.tap do |tags|
      if current_user.present?
        tags[:sign_in_method] = current_user.identity.sign_in[:service_name]
        tags[:sign_in_acct_type] = current_user.identity.sign_in[:account_type]
      else
        tags[:sign_in_method] = 'not-signed-in'
      end
    end
  end

  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    level = normalize_level(level)
    formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
    rails_logger(level, formatted_message)

    set_context(extra_context, tags_context)
    Raven.capture_message(message, level: level)
  end

  def log_exception_to_sentry(exception, extra_context = {}, tags_context = {}, level = 'error')
    level = 'info' if client_error?(extra_context[:va_exception_errors])
    level = normalize_level(level)

    log_to_rails(exception, level)

    set_context(extra_context, tags_context)
    Raven.capture_exception(exception.cause.presence || exception, level: level)
  end

  def log_to_rails(exception, level = 'error')
    if exception.is_a? Common::Exceptions::BackendServiceException
      rails_logger(level, exception.message, exception.errors, exception.backtrace)
    else
      rails_logger(level, "#{exception.message}.")
    end
    rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
  end

  def normalize_level(level)
    level = level.to_s
    return 'warning' if level == 'warn'

    level
  end

  def rails_logger(level, message, errors = nil, backtrace = nil)
    # rails logger uses 'warn' instead of 'warning'
    level = 'warn' if level == 'warning'
    if errors.present?
      error_details = errors.first.attributes.compact.reject { |_k, v| v.try(:empty?) }
      Rails.logger.send(level, message, error_details.merge(backtrace: backtrace))
    else
      Rails.logger.send(level, message)
    end
  end

  def set_context(extra_context, tags_context)
    Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
    Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
  end

  def non_nil_hash?(h)
    h.is_a?(Hash) && !h.empty?
  end

  private

  def client_error?(va_exception_errors)
    va_exception_errors.present? &&
      va_exception_errors.detect { |h| client_error_status?(h[:status]) || evss_503?(h[:code], h[:status]) }.present?
  end

  def client_error_status?(status)
    (400..499).cover?(status.to_i)
  end

  def evss_503?(code, status)
    (code == 'EVSS503' && status.to_i == 503)
  end
end
