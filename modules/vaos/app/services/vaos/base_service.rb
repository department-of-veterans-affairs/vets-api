# frozen_string_literal: true

module VAOS
  class BaseService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging

    attr_accessor :user

    STATSD_KEY_PREFIX = 'api.vaos'

    # This method is deprecated... Will remove in future commit in favor of new
    def self.for_user(user)
      new(user)
    end

    def initialize(user)
      @user = user
    end

    private

    def config
      VAOS::Configuration.instance
    end

    def headers
      session_token = user_service.session(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => session_token }
    end

    def user_service
      VAOS::UserService.new
    end
  end
end
