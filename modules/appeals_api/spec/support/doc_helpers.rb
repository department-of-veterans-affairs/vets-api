# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module DocHelpers
  # Makes UUIDs and timestamps constant, to reduce cognitive overhead when working with rswag output files
  def normalize_appeal_response(response)
    data = JSON.parse(response.body, symbolize_names: true)
    return data unless data[:data]

    data[:data][:id] = '00000000-1111-2222-3333-444444444444'
    data[:data][:attributes][:updatedAt] = '2020-01-02T03:04:05.067Z'
    data[:data][:attributes][:createdAt] = '2020-01-02T03:04:05.067Z'
    data
  end

  def normalize_evidence_submission_response(response)
    data = JSON.parse(response.body, symbolize_names: true)
    return data unless data.dig(:data, :attributes, :appealId)

    data[:data][:id] = '55555555-6666-7777-8888-999999999999'
    data[:data][:attributes][:appealId] = '00000000-1111-2222-3333-444444444444'
    data[:data][:attributes][:createdAt] = '2020-01-02T03:04:05.067Z'
    data[:data][:attributes][:updatedAt] = '2020-01-02T03:04:05.067Z'
    data
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
  # @option opts [String] :cassette The name of the cassette to use, if any
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
        VCR.use_cassette(opts[:cassette]) do
          with_rswag_auth(scopes, valid:) { submit_request(example.metadata) }
        end
      else
        with_rswag_auth(scopes, valid:) { submit_request(example.metadata) }
      end
    end

    it opts[:desc] do |example|
      assert_response_matches_metadata(example.metadata) unless opts[:skip_match]
    end

    after do |example|
      r = if opts[:response_wrapper]
            send(opts[:response_wrapper], response)
          else
            JSON.parse(response.body, symbolize_names: true)
          end

      # Removes 'potentialPactAct' from example for production docs
      unless wip_doc_enabled?(:sc_v2_potential_pact_act)
        case r
        when String
          r = r.gsub(/"potentialPactAct":{"type":"boolean"},/, '')
        when Hash
          r.tap do |s|
            s.dig(*%i[properties data properties attributes properties])&.delete(:potentialPactAct)
          end
        end
      end

      example.metadata[:response][:content] = if opts[:extract_desc]
                                                {
                                                  'application/json' => {
                                                    examples: { "#{opts[:desc]}": { value: r } }
                                                  }
                                                }
                                              else
                                                { 'application/json' => { example: r } }
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

  def wip_doc_enabled?(sym)
    DocHelpers.wip_doc_enabled?(sym)
  end

  def self.doc_suffix
    ENV['RSWAG_ENV'] == 'dev' ? '_dev' : ''
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
end
# rubocop:enable Metrics/ModuleLength
