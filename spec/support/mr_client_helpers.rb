# frozen_string_literal: true

require 'medical_records/client'

module MedicalRecords
  module ClientHelpers
    TOKEN = 'SESSION_TOKEN'

    def authenticated_client
      MedicalRecords::Client.new(session: { user_id: 11_898_795,
                                            expires_at: Time.current + (60 * 60),
                                            token: TOKEN })
    end
  end
end
