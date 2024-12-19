# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyRequestBlueprint < Blueprinter::Base
        view :create do
          field :id do |request|
            request['id']
          end

          field :type do
            'power-of-attorney-request'
          end

          field :attributes do |request|
            request.except('id')
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
