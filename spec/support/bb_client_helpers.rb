# frozen_string_literal: true

require 'bb/client'

module BB
  module ClientHelpers
    TOKEN = 'GkuX2OZ4dCE=48xrH6ObGXZ45ZAg70LBahl7CjswZe8SZGKMUVFIu8='

    def authenticated_client
      BB::Client.new(session: { user_id: 123, expires_at: Time.current + (60 * 60), token: TOKEN })
    end
  end
end 