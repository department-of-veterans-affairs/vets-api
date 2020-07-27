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
      { 'Referer' => referrer, 'X-VAMF-JWT' => session_token, 'X-Request-ID' => RequestStore.store['request_id'] }
    end

    # Set the referrer (Referer header) to distinguish review instance, staging, etc from logs
    def referrer
      if Settings.hostname.ends_with?('.gov')
        "https://#{Settings.hostname}".gsub('vets', 'va')
      else
        'https://review-instance.va.gov' # VAMF rejects Referer that is not valid; such as those of review instances
      end
    end

    def user_service
      VAOS::UserService.new(user)
    end
  end
end
