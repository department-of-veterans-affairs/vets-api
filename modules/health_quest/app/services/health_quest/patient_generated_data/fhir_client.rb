# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module FHIRClient
      def url
        "#{Settings.hqva_mobile.lighthouse.url}/smart-pgd-fhir/v1"
      end

      def client
        FHIR::Client.new(url).tap do |client|
          client.use_r4
          client.default_json
          client.additional_headers = headers&.merge(accept_headers)
        end
      end

      def accept_headers
        { 'Accept' => 'application/json+fhir' }
      end

      def headers
        raise NotImplementedError "#{self.class} should have implemented headers ..."
      end
    end
  end
end
