# frozen_string_literal: true

module UnifiedHealthData
  module Serializers
    class ConditionSerializer
      include JSONAPI::Serializer

      set_type :condition
      attributes :date, :name, :provider, :facility, :comments
    end
  end
end
