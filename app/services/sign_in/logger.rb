# frozen_string_literal: true

require 'sign_in/constants/auth'

module SignIn
  class Logger
    def info_log(message, context = {})
      context[:timestamp] = Time.zone.now.to_s
      Rails.logger.info(message, context)
    end

    def access_token_log(message, token, context = {})
      token_values = {
        token_type: 'Access',
        user_id: token.user_uuid,
        session_id: token.session_handle,
        access_token_id: token.uuid
      }
      context = context.merge(token_values)
      info_log(message, context)
    end

    def refresh_token_log(message, token, context = {})
      token_values = {
        token_type: 'Refresh',
        user_id: token.user_uuid,
        session_id: token.session_handle
      }
      context = context.merge(token_values)
      info_log(message, context)
    end

    def authorize_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end

    def callback_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end

    def token_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_TOKEN_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end

    def refresh_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_REFRESH_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end

    def revoke_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_REVOKE_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end

    def introspect_stats(status, tags)
      statsd_code = if status == :success
                      Constants::Statsd::STATSD_SIS_INTROSPECT_SUCCESS
                    else
                      Constants::Statsd::STATSD_SIS_INTROSPECT_FAILURE
                    end
      StatsD.increment(statsd_code, tags: tags)
    end
  end
end
