# frozen_string_literal: true

class Swagger::V1::Schemas::IncomeLimits
  include Swagger::Blocks

  swagger_schema :IncomeLimitThresholds do
    key :required, [:data]
    property :data do
      key :type, :array
      items do
        property :pension_threshold, type: :integer, example: 19_320
        property :national_threshold, type: :integer, example: 43_990
        property :gmt_threshold, type: :integer, example: 61_900
      end
    end
  end

  swagger_schema :ZipCodeIsValid do
    property :zip_is_valid, type: :boolean
  end
end
