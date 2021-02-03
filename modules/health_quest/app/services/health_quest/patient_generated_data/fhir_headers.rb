# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module FHIRHeaders
      def auth_header
        {
          'Authorization' => "Bearer #{access_token}"
        }
      end

      def content_type_header
        {
          'Content-Type' => 'application/fhir+json'
        }
      end
    end
  end
end
