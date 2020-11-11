# frozen_string_literal: true

module HealthQuest
  module Pgd
    module Patient
      class MapQuery
        include Pgd::FhirClient

        attr_reader :headers

        def self.build(headers)
          new(headers)
        end

        def initialize(headers)
          @headers = headers
        end

        def get(id)
          client.read(dstu2_model, id)
        end

        def dstu2_model
          FHIR::DSTU2::Patient
        end
      end
    end
  end
end
