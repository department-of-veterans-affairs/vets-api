# frozen_string_literal: true

require 'medical_records/client'

module MedicalRecords
  module ClientHelpers
    TOKEN = 'SESSION_TOKEN'

    def authenticated_client
      MedicalRecords::Client.new(session: { user_id: 11_898_795,
                                            icn: '123ABC',
                                            patient_fhir_id: 2952,
                                            expires_at: Time.current + (60 * 60),
                                            token: TOKEN })
    end

    VCR.configure do |config|
      config.register_request_matcher :wildcard_path do |request1, request2|
        # Removes the user id and icn after `/isValidSMUser/` to handle any user id and icn
        path1 = request1.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
        path2 = request2.uri.gsub(%r{/isValidSMUser/.*}, '/isValidSMUser')
        path1 == path2
      end
    end
  end
end
