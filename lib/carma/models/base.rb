# frozen_string_literal: true

module CARMA
  module Models
    class Base
      class_attribute :request_payload_keys, default: []
      class_attribute :request_payload_after_hook

      def to_request_payload
        request_payload = request_payload_keys.each_with_object({}) do |key, result|
          value = send(key.to_s)
          value = value.to_request_payload if value.class.ancestors.include?(Base)

          result[key.to_s.camelize(:lower)] = value
        end

        request_payload_after_hook ? send(request_payload_after_hook, request_payload) : request_payload
      end

      # Hook allowing the inheriting class to set the attribute keys that should be included when
      # parsing the object to a request_payload object.
      def self.request_payload_key(key, *keys)
        # Assignment vs concat is important for the inheriting class
        # to have it's own array vs referencing Base.request_payload_keys
        self.request_payload_keys += [key, *keys]
      end

      def self.after_to_request_payload(method_sym)
        self.request_payload_after_hook = method_sym
      end
    end
  end
end
