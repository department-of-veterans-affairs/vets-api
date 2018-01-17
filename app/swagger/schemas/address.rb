# frozen_string_literal: true

module Swagger
  module Schemas
    class Address
      include Swagger::Blocks

      swagger_schema :Address do
        key :required, [:data]

        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            property :address do
              property :type, type: :string, enum:
                %w[
                  DOMESTIC
                  INTERNATIONAL
                  MILITARY
                ], example: 'DOMESTIC'
              property :address_effective_date, type: :string, example: '1973-01-01T05:00:00.000+00:00'
              property :address_one, type: :string, example: '140 Rock Creek Church Rd NW'
              property :address_two, type: :string, example: ''
              property :address_three, type: :string, example: ''
              property :city, type: :string, example: 'Washington'
              property :state_code, type: :string, example: 'DC'
              property :zip_code, type: :string, example: '20011'
              property :zip_suffix, type: :string, example: '1865'
            end
            property :control_information do
              property :can_update, type: :boolean
              property :corp_avail_indicator, type: :boolean
              property :corp_rec_found_indicator, type: :boolean
              property :has_no_bdn_payments_indicator, type: :boolean
              property :is_competent_indicator, type: :boolean
              property :indentity_indicator, type: :boolean
              property :index_indicator, type: :boolean
              property :no_fiduciary_assigned_indicator, type: :boolean
              property :not_deceased_indicator, type: :boolean
            end
          end
        end
      end
    end
  end
end
