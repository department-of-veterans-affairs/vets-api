# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyBlueprint < Blueprinter::Base
        identifier :code
        field :name
        field :phone do |entity, _options|
          { number: entity[:phone_number] }
        end
        field :type

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
