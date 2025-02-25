# frozen_string_literal: true

require 'active_model'
require 'common/models/attribute_types/utc_time'

module Common
  # This is a base serialization class
  class Base
    extend ActiveModel::Naming
    include ActiveModel::Serialization
    include Comparable
    include Virtus.model(nullify_blank: true)

    attr_accessor :metadata, :errors_hash

    class << self
      def per_page(value = nil)
        @per_page ||= value || 10
      end

      def max_per_page(value = nil)
        @max_per_page ||= value || 100
      end

      def sortable_attributes
        @sortable_attributes ||= attribute_set.map do |attribute|
          next unless attribute.options[:sortable]

          sortable = attribute.options[:sortable].is_a?(Hash) ? attribute.options[:sortable] : { order: 'ASC' }
          if sortable[:default]
            @default_sort ||= sortable[:order] == 'DESC' ? "-#{attribute.name}" : attribute.name.to_s
          end
          [attribute.name.to_s, sortable[:order]]
        end.compact.to_h.with_indifferent_access
      end

      def default_sort
        @default_sort ||= begin
          sortable_attributes
          @default_sort
        end
      end

      def filterable_attributes
        @filterable_attributes ||= attribute_set.map do |attribute|
          [attribute.name.to_s, attribute.options[:filterable]] if attribute.options[:filterable]
        end.compact.to_h.with_indifferent_access
      end
    end

    def initialize(init_attributes = {})
      super(init_attributes[:data] || init_attributes)
      @metadata = init_attributes[:metadata] || {}
      @errors_hash = init_attributes[:errors] || {}
      @original_attributes = attributes
    end

    def changed?
      changed.any?
    end

    def changed
      attributes.map { |k, v| k if @original_attributes[k] != v }.compact
    end

    def changes
      changed.to_h { |k, _v| [k, [@original_attributes[k], attributes[k]]] }
    end
  end
end
