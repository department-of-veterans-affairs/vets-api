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
      attribute :detail, :string
      attribute :id, :integer
      attribute :href, :string
      attribute :code, :string
      attribute :source
      attribute :links, default: -> { [] }
      attribute :status, :string
      attribute :meta, :string

      validates :source, inclusion: { in: ->(_record) { [String, Hash, NilClass] } }, if: -> { source.present? }

      def initialize(attributes = {})
        attributes ||= {}
        # nullifies blank values
        attributes = attributes.transform_values(&:presence) if attributes.present?
        # filters unknown attributes from the attributes hash
        filtered_attributes = attributes.slice(*self.class.attribute_names.map(&:to_s))
                                        .merge(attributes.slice(*self.class.attribute_names.map(&:to_sym)))

        super(filtered_attributes)
      end

      def detail
        super.presence || title
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

      # return only those attributes that have non nil values
      def to_hash
        attributes.compact_blank.deep_symbolize_keys
      end
      alias to_h to_hash

    end
  end
end
