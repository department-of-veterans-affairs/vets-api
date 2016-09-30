# frozen_string_literal: true
require 'forwardable'
require 'common/models/comparable/descending'

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
      'not_eq' => :!=
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
      result = @data.select { |item|  finder(item, search) }
      metadata = @metadata.merge(filter: search)
      Collection.new(type, data: result, metadata: metadata, errors: errors)
    end

    def find_first_by(search = {})
      result = @data.detect { |item| finder(item, search) }
      return nil if result.nil?
      result.metadata = metadata
      result
    end

    def sortable_attributes
      type.attribute_set.map { |attribute| attribute.name.to_s }
    end

    def sort(sort_params, allowed: sortable_attributes)
      fields = sort_fields(sort_params, allowed)
      result = @data.sort_by do |item|
        fields.map do |k, v|
          v == 'ASC' ? item.send(k) : Descending.new(item.send(k))
        end
      end

      metadata = @metadata.merge(sort: fields)
      Collection.new(type, data: result, metadata: metadata, errors: errors)
    end

    def paginate(page: 1, per_page: 10)
      page = page.to_i
      per_page = per_page.to_i
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
        # raise exception if attribute is not supported by filter
        predicates.all? do |operator, expected_value|
          op = OPERATIONS_MAP.fetch(operator)
          mock_comparator_object.send("#{attribute}=", expected_value)
          actual_value.send(op, mock_comparator_object.send(attribute))
        end
      end
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

    def sort_fields(sort_params, allowed)
      fields = sort_params.to_s.split(',')
      ordered_fields = convert_fields_to_ordered_hash(fields)
      ordered_fields.select { |k, _| Array.wrap(allowed).include?(k) }
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
