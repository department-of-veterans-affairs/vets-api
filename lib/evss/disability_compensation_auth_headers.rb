# frozen_string_literal: true

module EVSS
  class DisabilityCompensationAuthHeaders
    # :nocov:
    def self.add_headers(auth_headers, user)
      headers = auth_headers.merge('va_eauth_gender' => gender(user))
      log_message_to_sentry('disability_headers', :info, headers)
      headers
    end

    def self.gender(user)
      log_message_to_sentry('disability_gender', :info, gender: user.gender)
      case user.gender
      when 'F'
        'FEMALE'
      when 'M'
        'MALE'
      else
        raise Common::Exceptions::UnprocessableEntity,
              detail: 'Gender is required & must be "FEMALE" or "MALE"',
              source: self.class, event_id: Raven.last_event_id
      end
    end

    def self.log_message_to_sentry(message, level, extra_context = {}, tags_context = {})
      level = level.to_s
      formatted_message = extra_context.empty? ? message : message + ' : ' + extra_context.to_s
      Rails.logger.send(level, formatted_message)
      if Settings.sentry.dsn.present?
        Raven.extra_context(extra_context) if non_nil_hash?(extra_context)
        Raven.tags_context(tags_context) if non_nil_hash?(tags_context)
        Raven.capture_message(message, level: level)
      end
    end
    # :nocov:
  end
end
