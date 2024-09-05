# frozen_string_literal: true

class ExtractStatusSerializer
  include JSONAPI::Serializer

  set_type :extract_statuses

  attributes :extract_type, :last_updated, :status, :created_on, :station_number
end
