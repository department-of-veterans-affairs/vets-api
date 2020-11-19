# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      class MapQuery
        include PatientGeneratedData::FHIRClient

        attr_reader :headers

        def self.build(headers)
          new(headers)
        end

        def initialize(headers)
          @headers = headers
        end

        def search(options = {})
          client.search(dstu2_model, search_options(options))
        end

        def dstu2_model
          FHIR::DSTU2::QuestionnaireResponse
        end

        def search_options(options)
          {
            search: {
              parameters: options
            }
          }
        end
      end
    end
  end
end
