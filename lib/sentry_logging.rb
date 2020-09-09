# frozen_string_literal: true

module SentryLogging
  def log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
    level = normalize_level(level)
    formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
    rails_logger(level, formatted_message)

    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_message(message, level: level)
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def log_exception_to_sentry(
    exception,
    extra_context = {},
    tags_context = {},
    level = 'error'
  )
    level = 'info' if extra_context.is_a?(Hash) && client_error?(extra_context[:va_exception_errors])
    level = normalize_level(level)
    if Settings.sentry.dsn.present?
      Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
      Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
      Raven.capture_exception(exception.cause.presence || exception, level: level)
    end

    if exception.is_a? Common::Exceptions::BackendServiceException
      rails_logger(level, exception.message, exception.errors, exception.backtrace)
    else
      rails_logger(level, "#{exception.message}.")
    end
    rails_logger(level, exception.backtrace.join("\n")) unless exception.backtrace.nil?
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/PerceivedComplexity

  def normalize_level(level)
    # https://docs.sentry.io/clients/ruby/usage/
    # valid raven levels: debug, info, warning, error, fatal
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

  def report_original_exception(exception)
    # report the original 'cause' of the exception when present
    if skip_sentry_exception_types.include?(exception.class)
      Rails.logger.error "#{exception.message}.", backtrace: exception.backtrace
    elsif exception.is_a?(Common::Exceptions::BackendServiceException) && exception.generic_error?
      # Warn about VA900 needing to be added to exception.en.yml
      log_message_to_sentry(exception.va900_warning, :warn, i18n_exception_hint: exception.va900_hint)
    end
  end

  def report_mapped_exception(exception, va_exception)
    extra = exception.respond_to?(:errors) ? { errors: exception.errors.map(&:to_hash) } : {}
    # Add additional user specific context to the logs
    if exception.is_a?(Common::Exceptions::BackendServiceException) && current_user.present?
      extra[:icn] = current_user.icn
      extra[:mhv_correlation_id] = current_user.mhv_correlation_id
    end
    va_exception_info = { va_exception_errors: va_exception.errors.map(&:to_hash) }
    log_exception_to_sentry(exception, extra.merge(va_exception_info))
  end

  def set_tags_and_extra_context
    RequestStore.store['request_id'] = request.uuid
    RequestStore.store['additional_request_attributes'] = {
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
        # account_type is filtered by sentry, becasue in other contexts it refers to a bank account type
        tags[:sign_in_acct_type] = current_user.identity.sign_in[:account_type]
      else
        tags[:sign_in_method] = 'not-signed-in'
      end
    end
  end
end
