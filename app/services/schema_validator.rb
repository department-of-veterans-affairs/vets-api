# frozen_string_literal: true

##
# Generic service object for validating data against a JSON schema
#
# This validator can work with:
# - Direct schema hashes
# - Swagger-defined schemas (by path and method)
#
# @example With direct schema
#   schema = { type: 'object', properties: { name: { type: 'string' } } }
#   validator = SchemaValidator.new(data, schema: schema)
#   validator.validate!
#
# @example With Swagger schema extraction
#   validator = SchemaValidator.new(data, swagger_path: '/v0/form214192', swagger_method: :post)
#   validator.valid? # => true/false
#
class SchemaValidator
  attr_reader :data, :errors

  ##
  # @param data [Hash] The data to validate
  # @param schema [Hash] Optional. Direct schema to validate against
  # @param swagger_path [String] Optional. Swagger path (e.g., '/v0/form214192')
  # @param swagger_method [Symbol] Optional. HTTP method (:get, :post, :put, :patch, :delete)
  # @param swagger_param_index [Integer] Optional. Parameter index in Swagger definition (default: 0)
  #
  def initialize(data, schema: nil, swagger_path: nil, swagger_method: nil, swagger_param_index: 0)
    @data = data
    @schema = schema
    @swagger_path = swagger_path
    @swagger_method = swagger_method
    @swagger_param_index = swagger_param_index
    @errors = []
  end

  ##
  # Validates the data and returns true/false
  #
  # @return [Boolean] true if valid, false otherwise
  def valid?
    validate_against_schema
    @errors.empty?
  end

  ##
  # Validates the data and raises an exception if invalid
  #
  # @raise [Common::Exceptions::SchemaValidationErrors] if validation fails
  # @return [true] if validation succeeds
  def validate!
    return true if valid?

    log_validation_errors
    raise Common::Exceptions::SchemaValidationErrors, @errors
  end

  private

  ##
  # Performs the actual schema validation
  #
  def validate_against_schema
    schema = resolved_schema
    return if schema.blank?

    schemer = JSONSchemer.schema(schema)
    validation_errors = schemer.validate(@data).to_a

    @errors = validation_errors.map do |error|
      error_details = error.symbolize_keys
      "#{error_details[:data_pointer]}: #{error_details[:error]}"
    end
  end

  ##
  # Resolves the schema from either direct input or Swagger extraction
  #
  # @return [Hash, nil] The resolved schema or nil
  def resolved_schema
    return @schema if @schema.present?
    return swagger_schema if @swagger_path.present? && @swagger_method.present?

    Rails.logger.warn('SchemaValidator: No schema or Swagger path provided')
    nil
  end

  ##
  # Extracts schema from Swagger documentation
  #
  # @return [Hash, nil] The extracted schema or nil
  def swagger_schema
    @swagger_schema ||= self.class.extract_swagger_schema(
      @swagger_path,
      @swagger_method,
      @swagger_param_index
    )
  end

  ##
  # Logs validation errors for debugging
  #
  def log_validation_errors
    context = if @swagger_path && @swagger_method
                "#{@swagger_method.to_s.upcase} #{@swagger_path}"
              else
                'custom schema'
              end

    Rails.logger.error("Schema validation errors for #{context}: #{@errors.join(', ')}")
  end

  ##
  # Extracts a schema from Swagger::Blocks for a given endpoint
  #
  # @param path [String] The API path (e.g., '/v0/form214192')
  # @param method [Symbol] The HTTP method (:get, :post, :put, :patch, :delete)
  # @param param_index [Integer] The parameter index (default: 0)
  # @return [Hash, nil] The schema hash or nil if extraction fails
  #
  def self.extract_swagger_schema(path, method, param_index = 0)
    Rails.application.eager_load! unless Rails.application.config.eager_load

    swagger_classes = ObjectSpace.each_object(Class).select do |klass|
      klass.included_modules.include?(Swagger::Blocks)
    end

    swagger_json = Swagger::Blocks.build_root_json(swagger_classes)
    swagger_json.dig(:paths, path.to_sym, method.to_sym, :parameters, param_index, :schema)
  rescue StandardError => e
    Rails.logger.error("Failed to extract Swagger schema for #{method.to_s.upcase} #{path}: #{e.message}")
    nil
  end

  ##
  # Cache for extracted Swagger schemas
  # Key format: "path:method:param_index"
  #
  @swagger_schema_cache = {}

  ##
  # Retrieves a Swagger schema with caching
  #
  # @param path [String] The API path
  # @param method [Symbol] The HTTP method
  # @param param_index [Integer] The parameter index
  # @return [Hash, nil] The cached or freshly extracted schema
  #
  def self.cached_swagger_schema(path, method, param_index = 0)
    cache_key = "#{path}:#{method}:#{param_index}"
    @swagger_schema_cache[cache_key] ||= extract_swagger_schema(path, method, param_index)
  end

  ##
  # Clears the Swagger schema cache (useful for testing)
  #
  def self.clear_cache!
    @swagger_schema_cache = {}
  end
end
