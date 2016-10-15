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
      def per_page(value)
        @per_page = value
      end

      def max_per_page(value)
        @max_per_page = value
      end

      def sortable_attributes
        @sortable_attributes ||= begin
          attribute_set.flat_map do |attribute|
            if attribute.options[:sortable]
              @default_sort ||= attribute.name.to_s if attribute.options[:sortable][:default]
              { attribute.name.to_s => attribute.options[:sortable][:order] }
            end
          end.compact
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
          attribute_set.flat_map do |attribute|
            { attribute.name.to_s => attribute.options[:filterable] } if attribute.options[:filterable]
          end.compact
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
