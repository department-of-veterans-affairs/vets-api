# frozen_string_literal: true

module VAOS
  module V2
    class VAOSSerializer
      def serialize(params, type)
        openstruct_to_hash(params, type)
      end

      def openstruct_to_hash(object, type, hash = {})
        case object
        when OpenStruct
          object.each_pair do |key, value|
            hash[key] = openstruct_to_hash(value, type)
          end
          result = {}
          result[:id] = hash[:id]
          result[:type] = type
          result[:attributes] = hash
          result
        when Array
          object.map { |v| openstruct_to_hash(v, type) }
        else object
        end
      end
    end
  end
end
