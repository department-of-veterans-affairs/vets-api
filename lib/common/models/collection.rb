# frozen_string_literal: true

require 'forwardable'
require 'common/models/comparable/ascending'
require 'common/models/comparable/descending'
require 'common/exceptions'

module Common
  # Wrapper for collection to keep aggregates
  class Collection
    include ActiveModel::Serialization
    extend ActiveModel::Naming
    extend Forwardable
    def_delegators :@data, :each, :map

    attr_reader :attributes
    attr_accessor :type, :data, :errors, :metadata
    alias members data
    alias to_h attributes
    alias to_hash attributes

    CACHE_NAMESPACE = 'common_collection'
    CACHE_DEFAULT_TTL = 3600 # default to 1 hour

    OPERATIONS_MAP = {
      'eq' => '==',
      'lteq' => '<=',
      'gteq' => '>=',
      'not_eq' => '!=',
      'match' => 'match'
    }.with_indifferent_access.freeze

    def initialize(klass = Array, data: [], metadata: {}, errors: {}, cache_key: nil)
      data = Array.wrap(data) # If data is passed in as nil, wrap it as an empty array
      @type = klass
      @attributes = data
      @metadata = metadata
      @errors = errors
      @cache_key = cache_key
      (@data = data) && return if defined?(::WillPaginate::Collection) && data.is_a?(WillPaginate::Collection)
      @data = data.collect do |element|
        element.is_a?(Hash) ? klass.new(element) : element
      end
    end

    def self.redis_namespace
      @redis_namespace ||= Redis::Namespace.new(CACHE_NAMESPACE, redis: Redis.current)
    end

    def redis_namespace
      @redis_namespace ||= self.class.redis_namespace
    end

    def self.fetch(klass, cache_key: nil, ttl: CACHE_DEFAULT_TTL)
      raise 'No Block Given' unless block_given?
      if cache_key
        json_string = redis_namespace.get(cache_key)
        if json_string.nil?
          collection = new(klass, yield.merge(cache_key: cache_key))
          cache(collection.serialize, cache_key, ttl)
          return collection
        else
          json_hash = Oj.load(json_string)
          new(klass, json_hash.merge('cache_key' => cache_key).symbolize_keys)
        end
      else
        new(klass, yield)
      end
    end

    def self.cache(json_hash, cache_key, ttl)
      redis_namespace.set(cache_key, json_hash)
      redis_namespace.expire(cache_key, ttl)
    end

    def self.bust(cache_keys)
      cache_keys = Array.wrap(cache_keys)
      cache_keys.map { |cache_key| redis_namespace.del(cache_key) }
    end

    def bust
      self.class.bust(@cache_key) if cached?
    end

    def cached?
      @cache_key.present?
    end

    def ttl
      @cache_key.present? ? redis_namespace.ttl(@cache_key) : nil
    end

    def find_by(filter = {})
      verify_filter_keys!(filter)
      result = @data.select { |item| finder(item, filter) }
      metadata = @metadata.merge(filter: filter)
      Collection.new(type, data: result, metadata: metadata, errors: errors)
    end

    def find_first_by(filter = {})
      verify_filter_keys!(filter)
      result = @data.detect { |item| finder(item, filter) }
      return nil if result.nil?
      result.metadata = metadata
      result
    end

    def sort(sort_params)
      fields = sort_fields(sort_params || type.default_sort)
      result = @data.sort_by do |item|
        fields.map do |k, v|
          v == 'ASC' ? Ascending.new(item.send(k)) : Descending.new(item.send(k))
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

    def serialize
      { data: data, metadata: metadata, errors: errors }.to_json
    end

    private

    def mock_comparator_object
      @mock_comparator_object ||= type.new
    end

    def finder(object, filter)
      filter.to_hash.all? do |attribute, predicates|
        actual_value = object.send(attribute)
        predicates.all? do |operator, expected_value|
          valid_operation =  type.filterable_attributes[attribute].include?(operator.to_s)
          raise Common::Exceptions::FilterNotAllowed, "#{operator} for #{attribute}" unless valid_operation

          op = OPERATIONS_MAP.fetch(operator)
          mock_comparator_object.send("#{attribute}=", expected_value)

          if op == 'match'
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

    def verify_filter_keys!(filter)
      failed_attributes = (filter.keys.map(&:to_s) - type.filterable_attributes.keys).join(', ')
      raise Common::Exceptions::FilterNotAllowed, failed_attributes unless failed_attributes.empty?
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
