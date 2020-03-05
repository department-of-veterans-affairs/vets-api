# frozen_string_literal: true

module VAOS
  class BaseService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging

    attr_accessor :user

    STATSD_KEY_PREFIX = 'api.vaos'

    def initialize(user)
      @user = user
    end

    private

    def config
      VAOS::Configuration.instance
    end

    def headers
      session_token = user_service.session
      { 'Referer' => referrer, 'X-VAMF-JWT' => session_token }
    end

    def referrer
      if Settings.hostname.ends_with?('.gov')
        "https://#{Settings.hostname}"
      else
        "http://#{Settings.hostname}"
      end
    end

    def user_service
      VAOS::UserService.new(user)
    end
  end
end
