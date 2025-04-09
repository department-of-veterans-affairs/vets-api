# frozen_string_literal: true

require 'sm/client'

module SM
  module ClientHelpers
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahl7CjswZe8SZGKMUVFIu8='

    def authenticated_client
      SM::Client.new(session: { user_id: 123,
                                expires_at: Time.current + (60 * 60),
                                token: TOKEN })
    end
  end
end
