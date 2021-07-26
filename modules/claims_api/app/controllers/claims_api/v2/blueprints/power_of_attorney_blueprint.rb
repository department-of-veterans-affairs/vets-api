# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyBlueprint < Blueprinter::Base
        identifier :code
        field :name
        field :type
        field :phone do |entity, _options|
          { number: entity[:phone_number] }
        end

        transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
      end
    end
  end
end
