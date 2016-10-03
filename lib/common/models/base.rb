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
      attr_accessor :per_page, :max_per_page

      def sortable_attributes
        @sortable_attributes ||= attribute_set.map { |a| a.name.to_s if a.options[:sortable] }.compact
      end

      def filterable_attributes
        @filterable_attributes ||= attribute_set.map { |a| a.name.to_s if a.options[:filterable] }.compact
      end

      def default_sort
        @default_sort ||= (attribute_set.find { |a| a.options[:default_sort] } || attribute_set.first).name.to_s
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
