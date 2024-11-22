module LoadTesting
  class TokenManager
    def initialize(test_session)
      @test_session = test_session
    end

    def generate_tokens(count)
      count.times do
        create_test_user_tokens
      end
    end

    def refresh_tokens
      @test_session.test_tokens.each do |token|
        next unless token.needs_refresh?
        refresh_token(token)
      end
    end

    private

    def create_test_user_tokens
      auth_response = authenticate_test_user
      @test_session.test_tokens.create!(
        access_token: auth_response[:access_token],
        refresh_token: auth_response[:refresh_token],
        device_secret: auth_response[:device_secret],
        expires_at: 30.minutes.from_now
      )
    end

    def refresh_token(token)
      new_tokens = SignIn::SessionRefresher.new(
        refresh_token: token.refresh_token,
        device_secret: token.device_secret
      ).perform

      token.update!(
        access_token: new_tokens[:access_token],
        refresh_token: new_tokens[:refresh_token],
        expires_at: 30.minutes.from_now
      )
    end

    def authenticate_test_user
      # For development/testing, return mock tokens
      if Rails.env.development? || Rails.env.test?
        return {
          access_token: "test_access_token_#{SecureRandom.hex(8)}",
          refresh_token: "test_refresh_token_#{SecureRandom.hex(8)}",
          device_secret: "test_device_secret_#{SecureRandom.hex(8)}"
        }
      end

      # In production, use actual auth flow
      auth_service = SignIn::AuthenticationServiceRetriever.new(
        type: 'logingov',
        client_config: SignIn::ClientConfig.find_by(client_id: 'load_test_client')
      ).perform

      response = auth_service.token('test_code')
      {
        access_token: response[:access_token],
        refresh_token: response[:refresh_token],
        device_secret: response[:device_secret]
      }
    end
  end
end 