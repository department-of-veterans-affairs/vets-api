# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyBlueprint < Blueprinter::Base
        view :show do
          field :id, if: ->(_field_name, obj, _options) { obj[:id].present? }

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

        view :status do
          field :id do |poa|
            poa[:id]
          end

          field :type do
            'claimsApiPowerOfAttorneys'
          end

          field :attributes do |poa|
            {
              created_at: poa[:created_at],
              representative: {
                poa_code: poa[:current_poa]
              },
              status: poa[:status],
              errors: poa.errors,
              steps: poa.steps
            }
          end

          transform ClaimsApi::V2::Blueprints::Transformers::LowerCamelTransformer
        end
      end
    end
  end
end
