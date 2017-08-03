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
            key :required, [:countries]
            property :address do
              property :type, type: :string, enum: %w(
                D
                I
                M
              ), example: 'D'
              property :address_effective_date, type: :string, example: '2015-10-01T04:00:00.000+0000'
              property :address_one, type: :string, example: '140 Rock Creek Church Rd NW'
              property :address_two, type: :string, example: 'Building A'
              property :address_three, type: :string, example: 'Apt 514'
              property :city, type: :string, example: 'Washington'
              property :state_code, type: :string, example: 'DC'
              property :zip_code, type: :string, example: '20011'
              property :zip_suffix, type: :string, example: '1234'
              property :country_name, type: :string, example: 'USA'
              property :military_post_office_type_code, type: :string, enum: %w(
                APO
                FPO
                DPO
              ), example: 'APO'
              property :military_state_code, type: :string, enum: %w(
                AA
                AE
                AP
              ), example: 'AA'
            end
            property :control_information do
              property :corp_avail_indicator, type: :boolean, example: false
              property :corp_rec_found_indicator, type: :boolean, example: false
              property :death_dt_indicator, type: :boolean, example: false
              property :fiduciary_indicator, type: :boolean, example: false
              property :incompetent_indicator, type: :boolean, example: false
              property :indentity_indicator, type: :boolean, example: false
              property :index_indicator, type: :boolean, example: false
              property :received_bdn_payments_indicator, type: :boolean, example: false
            end
          end
        end
      end
    end
  end
end
