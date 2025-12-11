# frozen_string_literal: true

require 'active_model'

module Common
  module Exceptions
    # This class is used to construct the JSON API SPEC errors object used for exceptions
    class SerializableError
      include ActiveModel::Model
      include ActiveModel::Serialization
      include ActiveModel::Attributes

      attribute :title, :string
      attribute :detail
      attribute :id, :integer
      attribute :href, :string
      attribute :code, :string
      attribute :source
      attribute :links, default: -> { [] }
      attribute :status, :string
      attribute :meta

      def initialize(attributes = {})
        attributes ||= {}
        # nullifies blank values like Virtus
        attributes = attributes.reject { |_, v| v.to_s.empty? } if attributes.present?

        # set default value for detail only if not provided
        attributes[:detail] = attributes[:title] unless attributes.key?(:detail) || attributes.key?('detail')

        # filters unknown attributes from the attributes hash
        normalized_attributes = attributes.transform_keys(&:to_sym)
        filtered_attributes = normalized_attributes.slice(*self.class.attribute_names.map(&:to_sym))

        super(filtered_attributes)
      end

      def source=(value)
        if value.blank?
          super(nil)
        elsif value.is_a?(String) || value.is_a?(Hash)
          super(value)
        else
          raise ArgumentError, "source must be a String or Hash, got #{value.class}"
        end
      end

      def links=(value)
        if value.blank?
          super([])
        else
          coerced = case value
                    when Array
                      value.map(&:to_s)
                    else
                      [value.to_s]
                    end

          super(coerced)
        end
      end

      def [](key)
        public_send(key)
      rescue NoMethodError
        nil
      end

      def attributes
        super.symbolize_keys
      end

      # return only those attributes that have present values
      def to_hash
        attributes.map { |k, _| [k, send(k)] if send(k).present? }.compact.to_h
      end
      alias to_h to_hash
    end
  end
end
