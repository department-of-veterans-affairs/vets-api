# frozen_string_literal: true

module MyHealth
  module V1
    class EligibleDataClassesSerializer
      include JSONAPI::Serializer

      set_type :eligible_data_classes
      set_id { '' }

      attribute :data_classes do |object|
        object.map(&:name)
      end
    end
  end
end
