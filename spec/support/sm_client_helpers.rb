# frozen_string_literal: true

module SM
  module ClientHelpers
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahi7CjswZe8SZGKMUVFIU88='

    def authenticated_client
      SM::Client.new(session: { user_id: 123,
                                expires_at: Time.current + 60 * 60,
                                token: TOKEN })
    end
  end
end
