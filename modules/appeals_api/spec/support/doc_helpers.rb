# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module DocHelpers
  NORMALIZED_DATE = '2020-01-02T03:04:05.067Z'

  def normalize_timestamp_attrs(attrs)
    if attrs[:updatedAt].present?
      attrs[:updatedAt] = NORMALIZED_DATE
    elsif attrs[:updateDate].present?
      attrs[:updateDate] = NORMALIZED_DATE
    end

    if attrs[:createdAt].present?
      attrs[:createdAt] = NORMALIZED_DATE
    elsif attrs[:createDate].present?
      attrs[:createDate] = NORMALIZED_DATE
    end

    attrs
  end

  def normalize_appeal_data(appeal_data)
    appeal_data[:id] = '00000000-1111-2222-3333-444444444444'
    appeal_data[:attributes] = normalize_timestamp_attrs(appeal_data[:attributes])
    appeal_data
  end

  # Makes UUIDs and timestamps constant, to reduce cognitive overhead when working with rswag output files
  def normalize_appeal_response(response)
    body = JSON.parse(response.body, symbolize_names: true)
    return body unless body[:data]

    body[:data] = if body[:data].is_a?(Array)
                    body[:data].map { |appeal_data| normalize_appeal_data(appeal_data) }
                  else
                    normalize_appeal_data(body[:data])
                  end

    body
  end

  def normalize_evidence_submission_response(response)
    body = JSON.parse(response.body, symbolize_names: true)
    return body unless body.dig(:data, :attributes, :appealId)

    body[:data][:id] = '55555555-6666-7777-8888-999999999999'
    body[:data][:attributes] = normalize_timestamp_attrs(body[:data][:attributes])
    body[:data][:attributes][:appealId] = '00000000-1111-2222-3333-444444444444'

    body
  end

  def raw_body(response)
    data = JSON.parse(response.body, symbolize_names: true)
    JSON.dump(data)
  end

  # NOTE: you must set `let(:Authorization) { 'Bearer <any-value-here>' }` in combination with this helper
  def with_rswag_auth(scopes = %w[], valid: true, &block)
    if scopes.any?
      with_openid_auth(scopes, valid:) do |auth_header|
        block.call(auth_header)
      end
    else
      block.call
    end
  end

  def self.oauth_security_config(scopes = [])
    [{ productionOauth: scopes }, { sandboxOauth: scopes }, { bearer_token: [] }]
  end

  def self.decision_reviews_security_config
    [{ apikey: [] }]
  end

  # @param [Hash] opts
  # @option opts [String|String[]] :cassette The name(s) of the cassette(s) to use, if any
  # @option opts [String] :desc The description of the test. Required.
  # @option opts [Boolean] :extract_desc Whether to use the example name
  # @option opts [Symbol] :response_wrapper Method name to wrap the response, to modify the output of the example
  # @option opts [Array<String>] :scopes OAuth scopes to use when making the request, if any
  # @option opts [Boolean] :skip_match Whether to skip the match metadata assertion
  # @option opts [Boolean] :token_valid Whether the OAuth token (if any) should be recognized as valid
  shared_examples 'rswag example' do |opts|
    before do |example|
      scopes = opts.fetch(:scopes, [])
      valid = opts.fetch(:token_valid, true)
      if opts[:cassette]
        cassettes = opts[:cassette].is_a?(String) ? [opts[:cassette]] : opts[:cassette]

        cassettes.each { |c| VCR.insert_cassette(c) }
        with_rswag_auth(scopes, valid:) { submit_request(example.metadata) }
        cassettes.each { |c| VCR.eject_cassette(c) }
      else
        with_rswag_auth(scopes, valid:) { submit_request(example.metadata) }
      end
    end

    it opts[:desc] do |example|
      assert_response_matches_metadata(example.metadata) unless opts[:skip_match]
    end

    after do |example|
      content_type = opts[:content_type].presence || 'application/json'

      r = if opts[:response_wrapper]
            send(opts[:response_wrapper], response)
          elsif content_type == 'application/json'
            JSON.parse(response.body, symbolize_names: true)
          end

      example.metadata[:response][:content] = if opts[:extract_desc]
                                                {
                                                  content_type => { examples: { "#{opts[:desc]}": { value: r } } }
                                                }
                                              else
                                                { content_type => { example: r } }
                                              end
    end
  end

  shared_examples 'rswag 500 response' do
    response '500', 'Internal Server Error' do
      schema '$ref' => '#/components/schemas/errorModel'

      after do |example|
        example.metadata[:response][:content] = {
          'application/json' => { example: { errors: [{ title: 'Internal server error',
                                                        detail: 'Internal server error',
                                                        code: '500',
                                                        status: '500' }] } }
        }
      end

      it 'returns a 500 response' do
        # No-Op
      end
    end
  end

  def self.wip_doc_enabled?(sym)
    # Only block doc generation if we still flag it as a WIP
    return true unless Settings.modules_appeals_api.documentation.wip_docs&.include?(sym.to_s)

    return false if ENV['WIP_DOCS_ENABLED'].nil?

    enabled_docs = ENV['WIP_DOCS_ENABLED'].split(',').map(&:to_sym)
    return false if enabled_docs.blank?

    enabled_docs.include?(sym)
  end

  delegate :wip_doc_enabled?, to: :DocHelpers

  def self.doc_suffix
    ENV['RSWAG_ENV'] == 'dev' ? '_dev' : ''
  end

  def self.doc_url_prefix
    ENV['RSWAG_ENV'] == 'dev' ? 'dev-' : ''
  end

  # Given a JSON schema hash and a path to a value inside it, find it and resolve any +$ref+s by merging them in
  # @param [Object] parent_schema - Full JSON schema as a hash
  # @param [Array<String>] value_keys - Path to dig for the value to resolve within the +parent_schema+
  # @return [Hash] - JSON schema for the given value without any $refs
  def _resolve_value_schema(parent_schema, *value_keys)
    value_schema = parent_schema.dig(*value_keys)
    raise "Unable to resolve schema at path #{value_keys.join('/')}" if value_schema.blank?

    if (parts = value_schema['allOf'])
      value_schema = parts.reduce(:merge)
    end

    return value_schema unless (ref = value_schema.delete('$ref'))

    if ref.end_with? '.json' # shared schema
      shared_schema = JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v0', ref)))
      shared_schema.dig('properties', ref.gsub('.json', '')).merge(value_schema)
    elsif ref.start_with? '#/' # reference within parent schema
      _resolve_value_schema(parent_schema, *ref.slice(2..).split('/')).merge(value_schema)
    else
      raise "Unable to resolve schema at #/#{value_keys.join('/')}"
    end
  end

  HOISTED_OAS_KEYS = %w[description required deprecated allowEmptyValue example].freeze

  # Generates a swagger parameter configuration based on the JSON schema for a value. See formats:
  # - JSON schema object: https://json-schema.org/understanding-json-schema/reference/object.html
  # - Swagger parameter config: https://swagger.io/specification/#parameter-object
  # @param [String] json_schema_path - Path to a JSON schema file within the appeals_api's schemas directory
  # @param [Array<String>] value_keys - Path to dig for the parameter value within the JSON schema
  # @return [Hash] - Rswag parameter config for the given value
  def parameter_from_schema(json_schema_path, *value_keys)
    parent_schema = JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', json_schema_path)))
    value_schema = _resolve_value_schema(parent_schema, *value_keys)
    name = value_keys.last
    param_config = { name: }
    HOISTED_OAS_KEYS.each { |key| param_config[key] = value_schema.delete(key) if value_schema[key] }
    param_config[:required] = true if parent_schema['required']&.include? name
    param_config[:schema] = value_schema
    param_config.deep_symbolize_keys
  end

  # Renames all keys in a hash from the +old_key+ to the +new_key+
  # This is here only to facilitate reuse of schemas in rswag docs before segmented APIs are split to the LHDI project
  # @param [Hash] hash - The hash
  # @param [String] old_key - Key to rename
  # @param [String] new_key - New name
  # @return [Hash] - An updated copy of the hash
  def deep_replace_key(hash, old_key, new_key)
    result = {}
    hash.each do |key, value|
      if key == old_key
        result[new_key] = value
      elsif value.is_a?(Hash) || (value.is_a?(Array) && value.any? { |v| v.is_a? Hash })
        result[key] = deep_replace_key(value, old_key, new_key)
      else
        result[key] = value
      end
    end
    result
  end
end
# rubocop:enable Metrics/ModuleLength
