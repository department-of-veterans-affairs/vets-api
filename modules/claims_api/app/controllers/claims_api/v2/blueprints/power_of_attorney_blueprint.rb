# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyBlueprint < Blueprinter::Base
        identifier :id

        field :type

        field :attributes do |poa, _options|
          {
            code: poa[:code],
            name: poa[:name],
            phone_number: poa[:phone_number]
          }
        end

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
