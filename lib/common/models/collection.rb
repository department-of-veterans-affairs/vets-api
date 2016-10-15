# frozen_string_literal: true
require 'forwardable'
require 'common/models/comparable/descending'
require 'common/exceptions'

module Common
  # Wrapper for collection to keep aggregates
  class Collection
    include ActiveModel::Serialization
    extend ActiveModel::Naming
    extend Forwardable
    def_delegators :@data, :each, :map

    attr_reader :data, :type, :attributes
    attr_accessor :errors, :metadata
    alias members data
    alias to_h attributes
    alias to_hash attributes

    OPERATIONS_MAP = {
      'eq' => :==,
      'lteq' => :<=,
      'gteq' => :>=,
      'not_eq' => :!=,
      'match' => :match
    }.with_indifferent_access.freeze

    def initialize(klass = Array, data: [], metadata: {}, errors: {})
      @type = klass
      @attributes = data
      @metadata = metadata
      @errors = errors
      (@data = data) && return if defined?(::WillPaginate::Collection) && data.is_a?(WillPaginate::Collection)
      @data = data.collect do |element|
        element.is_a?(Hash) ? klass.new(element) : element
      end
    end

    def find_by(search = {})
      verify_search_params!(search)
      result = @data.select { |item| finder(item, search) }
      metadata = @metadata.merge(filter: search)
      Collection.new(type, data: result, metadata: metadata, errors: errors)
    end

    def find_first_by(search = {})
      verify_search_params!(search)
      result = @data.detect { |item| finder(item, search) }
      return nil if result.nil?
      result.metadata = metadata
      result
    end

    def sort(sort_params)
      fields = sort_fields(sort_params || type.default_sort)
      result = @data.sort_by do |item|
        fields.map do |k, v|
          v == 'ASC' ? item.send(k) : Descending.new(item.send(k))
        end
      end

      metadata = @metadata.merge(sort: fields)
      Collection.new(type, data: result, metadata: metadata, errors: errors)
    end

    def paginate(page: nil, per_page: nil)
      page = page.try(:to_i) || 1
      max_per_page = type.max_per_page || 100
      per_page = [(per_page.try(:to_i) || type.per_page || 10), max_per_page].min
      collection = paginator(page, per_page)
      Collection.new(type, data: collection, metadata: metadata.merge(pagination_meta(page, per_page)), errors: errors)
    end

    private

    def mock_comparator_object
      @mock_comparator_object ||= type.new
    end

    def finder(object, search)
      search.all? do |attribute, predicates|
        actual_value = object.send(attribute)
        predicates.all? do |operator, expected_value|
          op = OPERATIONS_MAP.fetch(operator)
          mock_comparator_object.send("#{attribute}=", expected_value)

          if op == :match
            actual_value.downcase.include?(expected_value.downcase)
          else
            actual_value.send(op, mock_comparator_object.send(attribute))
          end
        end
      end
    rescue StandardError => e
      raise e if e.is_a?(Common::Exceptions::BaseError)
      raise Common::Exceptions::InvalidFiltersSyntax.new(nil, detail: 'The syntax for your filters is invalid')
    end

    def paginator(page, per_page)
      if defined?(::WillPaginate::Collection)
        WillPaginate::Collection.create(page, per_page, @data.length) do |pager|
          pager.replace @data[pager.offset, pager.per_page]
        end
      else
        @data[((page - 1) * per_page)...(page * per_page)]
      end
    end

    def pagination_meta(page, per_page)
      total_entries = @data.size
      total_pages = total_entries.zero? ? 1 : (total_entries / per_page.to_f).ceil
      { pagination: { current_page: page, per_page: per_page, total_pages: total_pages, total_entries: total_entries } }
    end

    def sort_fields(params)
      params = Array.wrap(params)
      not_allowed = params.select { |p| sort_type_allowed?(p) }.join(', ')
      raise Common::Exceptions::InvalidSortCriteria.new(type.name, not_allowed) unless not_allowed.empty?
      convert_fields_to_ordered_hash(params)
    end

    def sort_type_allowed?(sort_param)
      !type.sortable_attributes.include?(sort_param.delete('-'))
    end

    def verify_search_params!(search)
      filter_not_allowed = (search.keys.map(&:to_s) - type.filterable_attributes).join(', ')
      raise Common::Exceptions::FilterNotAllowed, filter_not_allowed unless filter_not_allowed.empty?
      filter_syntax_invalid = (search.values.map(&:keys).flatten - OPERATIONS_MAP.keys).join(', ')
      raise Common::Exceptions::InvalidFiltersSyntax, filter_syntax_invalid unless filter_syntax_invalid.empty?
    end

    def convert_fields_to_ordered_hash(fields)
      fields.each_with_object({}) do |field, hash|
        if field.start_with?('-')
          field = field[1..-1]
          hash[field] = 'DESC'
        else
          hash[field] = 'ASC'
        end
      end
    end
  end
end
