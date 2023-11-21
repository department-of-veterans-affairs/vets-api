# frozen_string_literal: true

module Avs
  class V0::Schemas::AvsSearchResult
    include Swagger::Blocks

    swagger_schema :AvsSearchResult do
      key :required, [:path]

      property :path, type: :string do
        key :example, '/my-health/medical-records/care-notes/avs/9A7AF40B2BC2471EA116891839113252'
      end
    end
  end
end
