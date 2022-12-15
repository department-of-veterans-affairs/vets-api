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
    if DocHelpers.decision_reviews?
      block.call
    else
      with_openid_auth(scopes, valid: valid) do |auth_header|
        block.call(auth_header)
      end
    end
  end

  def self.security_config(oauth_scopes = [])
    config = [{ apikey: [] }]
    return config if DocHelpers.decision_reviews?

    config + [{ productionOauth: oauth_scopes }, { sandboxOauth: oauth_scopes }, { bearer_token: [] }]
  end

  # @param [Hash] opts
  # @option opts [String] :desc The description of the test. Required.
  # @option opts [Symbol] :response_wrapper Method name to wrap the response, to modify the output of the example
  # @option opts [Boolean] :extract_desc Whether to use the example name
  # @option opts [Boolean] :skip_match Whether to skip the match metadata assertion
  # @option opts [Array<String>] :scopes OAuth scopes to use when making the request, if any
  # @option opts [Boolean] :token_valid Whether the OAuth token (if any) should be recognized as valid
  shared_examples 'rswag example' do |opts|
    before do |example|
      with_rswag_auth(opts[:scopes], valid: opts.fetch(:token_valid, true)) do
        submit_request(example.metadata)
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

  def self.wip_doc_enabled?(sym, require_env_slug = false) # rubocop:disable Style/OptionalBooleanParameter
    # Only block doc generation if we still flag it as a WIP
    return true unless Settings.modules_appeals_api.documentation.wip_docs&.include?(sym.to_s)

    return false if ENV['WIP_DOCS_ENABLED'].nil?

    enabled_docs = ENV['WIP_DOCS_ENABLED'].split(',').map(&:to_sym)
    return false if enabled_docs.blank?

    if require_env_slug
      enabled_docs.include?(sym) && ENV.key?('API_NAME')
    else
      enabled_docs.include?(sym)
    end
  end

  def wip_doc_enabled?(sym)
    DocHelpers.wip_doc_enabled?(sym)
  end

  DOC_TITLES = {
    higher_level_reviews: 'Higher-Level Reviews',
    notice_of_disagreements: 'Notice of Disagreements',
    supplemental_claims: 'Supplemental Claims',
    contestable_issues: 'Contestable Issues',
    legacy_appeals: 'Legacy Appeals'
  }.freeze

  def self.api_name
    ENV['API_NAME']
  end

  # Note that if ENV['API_NAME'] is unset, we're assuming that we're building Decision Reviews V2 docs
  # (as opposed to docs for one of the individual segmented APIs)
  def self.decision_reviews?
    DocHelpers.api_name.nil?
  end

  def self.use_shared_schemas?
    !DocHelpers.decision_reviews?
  end

  def self.api_version
    DocHelpers.decision_reviews? ? 'v2' : 'v0'
  end

  def self.api_title
    return 'Decision Reviews' if DocHelpers.decision_reviews?

    DOC_TITLES[DocHelpers.api_name&.to_sym]
  end

  def self.api_tags
    if DocHelpers.decision_reviews?
      DOC_TITLES.values.collect { |title| { name: title, description: '' } }
    else
      [{ name: DOC_TITLES[DocHelpers.api_name.to_sym], description: '' }]
    end
  end

  def self.api_base_path_template
    if DocHelpers.decision_reviews?
      '/services/appeals/{version}/decision_reviews'
    else
      "/services/appeals/#{DocHelpers.api_name}/{version}"
    end
  end

  def self.api_base_path
    DocHelpers.api_base_path_template.gsub('{version}', DocHelpers.api_version)
  end

  def self.doc_suffix
    ENV['RSWAG_ENV'] == 'dev' ? '_dev' : ''
  end

  def self.output_directory_file_path(file_name)
    file_path = if DocHelpers.decision_reviews?
                  "app/swagger/appeals_api/#{DocHelpers.api_version}/#{file_name}"
                else
                  "app/swagger/#{DocHelpers.api_name}/#{DocHelpers.api_version}/#{file_name}"
                end
    AppealsApi::Engine.root.join(file_path).to_s
  end

  def self.api_description_file_path
    DocHelpers.output_directory_file_path("api_description#{DocHelpers.doc_suffix}.md")
  end

  def self.output_json_path
    # Note that rswag expects this path to be relative to the working directory when running the specs
    # rubocop:disable Layout/LineLength
    if DocHelpers.decision_reviews?
      "modules/appeals_api/app/swagger/appeals_api/#{DocHelpers.api_version}/swagger#{DocHelpers.doc_suffix}.json"
    else
      "modules/appeals_api/app/swagger/#{DocHelpers.api_name}/#{DocHelpers.api_version}/swagger#{DocHelpers.doc_suffix}.json"
    end
    # rubocop:enable Layout/LineLength
  end

  def self.openapi_version
    DocHelpers.decision_reviews? ? '3.0.0' : '3.1.0'
  end
end
# rubocop:enable Metrics/ModuleLength
