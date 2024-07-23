# frozen_string_literal: true

module ClaimsApi
  module V2
    module Blueprints
      class PowerOfAttorneyRequestBlueprint < Blueprinter::Base
        class Veteran < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :first_name,
            :middle_name,
            :last_name
          )
        end

        class Representative < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :first_name,
            :last_name,
            :email
          )
        end

        class Decision < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :status,
            :declining_reason
          )

          field(
            :created_at,
            datetime_format: :iso8601.to_proc
          )

          association :created_by, blueprint: Representative
        end

        class Claimant < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :first_name,
            :last_name,
            :relationship_to_veteran
          )
        end

        class Address < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :city, :state, :zip, :country,
            :military_post_office,
            :military_postal_code
          )
        end

        class Attributes < Blueprinter::Base
          transform Transformers::LowerCamelTransformer

          fields(
            :power_of_attorney_code
          )

          field(
            :authorizes_address_changing,
            name: :is_address_changing_authorized
          )

          field(
            :authorizes_treatment_disclosure,
            name: :is_treatment_disclosure_authorized
          )

          association :veteran, blueprint: Veteran
          association :claimant, blueprint: Claimant
          association :claimant_address, blueprint: Address
          association :decision, blueprint: Decision

          field(
            :created_at,
            datetime_format: :iso8601.to_proc
          )
        end

        transform Transformers::LowerCamelTransformer

        identifier :id
        field(:type) { 'powerOfAttorneyRequest' }

        association :attributes, blueprint: Attributes do |poa_request|
          poa_request
        end
      end
    end
  end
end
