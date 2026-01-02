# frozen_string_literal: true

module UnifiedHealthData
  module Serializers
    class ConditionSerializer
      include JSONAPI::Serializer

      set_id :id
      set_type :condition
      attributes :id, :date, :name, :provider, :facility, :comments
    end
  end
end
