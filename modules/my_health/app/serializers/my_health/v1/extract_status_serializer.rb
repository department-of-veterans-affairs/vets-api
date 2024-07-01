# frozen_string_literal: true

module MyHealth
  module V1
    class ExtractStatusSerializer
      include JSONAPI::Serializer

      set_type :extract_status

      attributes :extract_type, :last_updated, :status, :created_on, :station_number
    end
  end
end
