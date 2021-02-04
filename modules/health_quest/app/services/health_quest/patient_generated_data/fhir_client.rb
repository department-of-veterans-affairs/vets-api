# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module FHIRClient
      def url
        "#{lighthouse.url}#{lighthouse.pgd_path}"
      end

      def client
        FHIR::Client.new(url).tap do |client|
          client.use_r4
          client.default_json
          client.additional_headers = headers
        end
      end

      def headers
        raise NotImplementedError "#{self.class} should have implemented headers ..."
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
