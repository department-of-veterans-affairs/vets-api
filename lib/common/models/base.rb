# frozen_string_literal: true
require 'active_model'
require 'common/models/attribute_types/utc_time'

module Common
  # This is a base serialization class
  class Base
    include Comparable
    include ActiveModel::Serialization
    extend ActiveModel::Naming
    include Virtus.model(nullify_blank: true)

    attr_reader :attributes
    attr_accessor :metadata, :errors_hash
    alias to_h attributes
    alias to_hash attributes

    class << self
      def per_page(value = nil)
        @per_page ||= value || 10
      end

      def max_per_page(value = nil)
        @max_per_page ||= value || 100
      end

      def sortable_attributes
        @sortable_attributes ||= begin
          Hash[attribute_set.map do |attribute|
            next unless attribute.options[:sortable]
            sortable = attribute.options[:sortable].is_a?(Hash) ? attribute.options[:sortable] : { order: 'ASC' }
            if sortable[:default]
              @default_sort ||= sortable[:order] == 'DESC' ? "-#{attribute.name}" : attribute.name.to_s
            end
            [attribute.name.to_s, sortable[:order]]
          end.compact].with_indifferent_access
        end
      end

      def default_sort
        @default_sort ||= begin
          sortable_attributes
          @default_sort
        end
      end

      def filterable_attributes
        @filterable_attributes ||= begin
          Hash[attribute_set.map do |attribute|
            [attribute.name.to_s, attribute.options[:filterable]] if attribute.options[:filterable]
          end.compact].with_indifferent_access
        end
      end
    end

    def initialize(attributes = {})
      @attributes = attributes[:data] || attributes
      @metadata = attributes[:metadata] || {}
      @errors_hash = attributes[:errors] || {}
      @attributes.each do |key, value|
        setter = "#{key.to_s.underscore}=".to_sym
        send(setter, value) if respond_to?(setter)
      end
    end
  end
end
