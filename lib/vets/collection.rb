# frozen_string_literal: true

#
# A Vets::Collection allows array of Vets::Model models to be
# sorted, filtered, or paginated.
#

require 'common/models/comparable/ascending'
require 'common/models/comparable/descending'
require 'vets/collections/finder'
require 'vets/collections/pagination'
require 'vets/collections/cacheable'

# This will be a replacement for Common::Collection
module Vets
  class Collection
    DEFAULT_PER_PAGE = 10
    DEFAULT_MAX_PER_PAGE = 100

    include Vets::Collections::Cacheable

    attr_accessor :records, :metadata, :errors, :size
    attr_reader :model_class

    alias data records
    alias members records
    alias type model_class

    def initialize(records, model_class = nil, metadata: {}, errors: {}, cache_key: nil)
      records = Array.wrap(records)
      @model_class = model_class || records.first&.class
      @metadata = metadata
      @errors = errors
      @cache_key = cache_key

      records = records.collect do |record|
        record.is_a?(Hash) ? model_class.new(record) : record
      end

      unless records.all? { |record| record.is_a?(@model_class) }
        raise ArgumentError, "All records must be instances of #{@model_class}"
      end

      @size = records.size
      @records = order(records)
    end

    def self.from_will_paginate(records)
      if defined?(::WillPaginate::Collection)
        error_message = 'Expected records to be instance of WillPaginate'
        raise ArgumentError, error_message unless records.is_a?(WillPaginate::Collection)
      end

      new(records)
    end

    # need to "alias" until all modules have switched over
    def sort(clauses = {})
      order(clauses)
    end

    # previously sort on Common::Collection
    def order(clauses = {})
      clauses = normalize_clauses(clauses)
      validate_sort_clauses(clauses)

      results = @records.sort_by do |record|
        clauses.map do |attribute, direction|
          value = record.public_send(attribute.to_sym)
          direction.to_sym == :asc ? Common::Ascending.new(value) : Common::Descending.new(value)
        end
      end

      fields = clauses.transform_keys(&:to_s).transform_values { |v| v.to_s.upcase }
      Vets::Collection.new(results, metadata: metadata.merge(sort: fields), errors:)
    end

    # previously find_by on Common::Collection
    def where(conditions = {})
      results = Vets::Collections::Finder.new(data: @records).all(conditions)
      Vets::Collection.new(results, metadata: metadata.merge({ filter: conditions }), errors:)
    end

    # previously find_first_by on Common::Collection
    def find_by(conditions = {})
      result = Vets::Collections::Finder.new(data: @records).first(conditions)
      result.metadata = metadata if result.respond_to?(:metadata)
      result
    end

    def paginate(page: nil, per_page: nil)
      pagination = Vets::Collections::Pagination.new(
        page: normalize_page(page),
        per_page: normalize_per_page(per_page),
        total_entries: @records.size,
        data: @records
      )
      Vets::Collection.new(pagination.data, metadata: metadata.merge(pagination.metadata), errors:)
    end

    def serialize
      { data: records, metadata:, errors: }.to_json
    end

    private

    def validate_sort_clauses(clauses)
      return if @records.empty?

      raise Common::Exceptions::InvalidSortCriteria.new(@model_class.to_s, clauses) if clauses.empty?

      clauses.each do |attribute, direction|
        unless @model_class.attribute_set.include?(attribute.to_sym)
          raise Common::Exceptions::InvalidSortCriteria.new(@model_class.to_s, attribute)
        end

        unless %i[asc desc].include?(direction)
          raise Common::Exceptions::InvalidSortCriteria.new(@model_class.to_s, attribute)
        end
      end
    end

    def normalize_page(page)
      page = page.to_i
      page.positive? ? page : 1
    end

    def normalize_per_page(per_page)
      per_page = per_page.to_i unless per_page.nil?
      [per_page || @model_class.try(:per_page) || DEFAULT_PER_PAGE, max_per_page].min
    end

    def max_per_page
      @model_class.try(:max_per_page) || DEFAULT_MAX_PER_PAGE
    end

    def normalize_clauses(input)
      input = @model_class.default_sort_criteria if input.blank?
      case input
      when String
        input.split(',').map(&:strip).each_with_object({}) do |clause, hash|
          normalize_clause_string(clause, hash)
        end
      when Array
        input.each_with_object({}) do |clause, hash|
          normalize_clause_string(clause, hash)
        end
      when Hash
        input.transform_keys(&:to_sym).transform_values(&:to_sym)
      end
    end

    def normalize_clause_string(clause, hash)
      if clause.start_with?('-')
        hash[clause[1..].to_sym] = :desc
      else
        hash[clause.to_sym] = :asc
      end
    end
  end
end
