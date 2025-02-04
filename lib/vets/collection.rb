# frozen_string_literal: true

#
# A Vets::Collection allows array of Vets::Model models to be
# sorted, filtered, or paginated.
#

require 'common/models/comparable/ascending'
require 'common/models/comparable/descending'
require 'vets/collections/finder'
require 'vets/collections/pagination'

# This will be a replacement for Common::Collection
module Vets
  class Collection
    DEFAULT_PER_PAGE = 10
    DEFAULT_MAX_PER_PAGE = 100

    attr_accessor :records, :metadata

    def initialize(records, metadata: {})
      records = Array.wrap(records)
      @model_class = records.empty? ? nil : records.first.class
      @metadata = metadata

      unless records.all? { |record| record.is_a?(@model_class) }
        raise ArgumentError, "All records must be instances of #{@model_class}"
      end

      @records = records.sort
    end

    def self.from_will_paginate(records)
      if defined?(::WillPaginate::Collection)
        error_message = 'Expected records to be instance of WillPaginate'
        raise ArgumentError, error_message unless records.is_a?(WillPaginate::Collection)
      end

      new(records)
    end

    def self.from_hashes(model_class, records)
      raise ArgumentError, 'Expected an array of hashes' unless records.all? { |r| r.is_a?(Hash) }

      records = records.map { |record| model_class.new(**record) }
      new(records)
    end

    def order(clauses = {})
      validate_sort_clauses(clauses)

      @records.sort_by do |record|
        clauses.map do |attribute, direction|
          value = record.public_send(attribute)
          direction == :asc ? Common::Ascending.new(value) : Common::Descending.new(value)
        end
      end
    end

    def where(conditions = {})
      results = Vets::Collections::Finder.new(data: @records).all(conditions)
      Vets::Collection.new(results, metadata: { filter: conditions })
    end

    def find_by(conditions = {})
      Vets::Collections::Finder.new(data: @records).first(conditions)
    end

    def paginate(page: nil, per_page: nil)
      pagination = Vets::Collections::Pagination.new(
        page: normalize_page(page),
        per_page: normalize_per_page(per_page),
        total_entries: @records.size,
        data: @records
      )
      Vets::Collection.new(pagination.data, metadata: pagination.metadata)
    end

    private

    def validate_sort_clauses(clauses)
      raise ArgumentError, 'Order must have at least one sort clause' if clauses.empty?

      clauses.each do |attribute, direction|
        raise ArgumentError, "Attribute #{attribute} must be a symbol" unless attribute.is_a?(Symbol)

        unless @records.first.respond_to?(attribute)
          raise ArgumentError, "Attribute #{attribute} does not exist on the model"
        end

        raise ArgumentError, "Direction #{direction} must be :asc or :desc" unless %i[asc desc].include?(direction)
      end
    end

    def normalize_page(page)
      page = page.to_i
      page.positive? ? page : 1
    end

    def normalize_per_page(per_page)
      [per_page || @model_class.try(:per_page) || DEFAULT_PER_PAGE, max_per_page].min
    end

    def max_per_page
      @model_class.try(:max_per_page) || DEFAULT_MAX_PER_PAGE
    end
  end
end
