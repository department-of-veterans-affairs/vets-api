# frozen_string_literal: true

require 'mobile/v0/messaging/client'

module Mobile
  module MessagingClientHelper
    TOKEN = 'STUBBED-SM-TOKEN'

    def authenticated_client
      Mobile::V0::Messaging::Client.new(session: { user_id: 123,
                                                   expires_at: Time.current + (60 * 60),
                                                   token: TOKEN })
    end
  end
end
