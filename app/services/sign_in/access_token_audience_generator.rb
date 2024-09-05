# frozen_string_literal: true

module SignIn
  class AccessTokenAudienceGenerator
    SHARED_SESSION_CLIENT_IDS_CACHE_KEY = 'sis_shared_sessions_client_ids'

    def initialize(client_config:)
      @client_config = client_config
    end

    def perform
      generate_audience
    end

    private

    attr_reader :client_config

    def generate_audience
      return shared_session_client_ids if client_config.shared_sessions?

      [client_config.client_id]
    end

    def shared_session_client_ids
      @shared_session_client_ids ||= Rails.cache.fetch(SHARED_SESSION_CLIENT_IDS_CACHE_KEY, expires_in: 5.minutes) do
        ClientConfig.where(shared_sessions: true).pluck(:client_id)
      end
    end
  end
end
