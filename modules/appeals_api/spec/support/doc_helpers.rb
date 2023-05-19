# frozen_string_literal: true

# These default values are used when running docs specs alongside other kinds of specs via rspec.
# When generating docs via rake tasks instead, we get these values from the environment set up in the rake task.
DEFAULT_CONFIG_VALUES = { api_name: 'decision_reviews', api_version: 'v2' }.freeze

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

  DECISION_REVIEWS_DOC_TITLES = {
    higher_level_reviews: 'Higher-Level Reviews',
    notice_of_disagreements: 'Notice of Disagreements',
    supplemental_claims: 'Supplemental Claims',
    contestable_issues: 'Contestable Issues',
    legacy_appeals: 'Legacy Appeals'
  }.freeze

  ALL_DOC_TITLES = DECISION_REVIEWS_DOC_TITLES.merge(
    {
      appealable_issues: 'Appealable Issues',
      appeals_status: 'Appeals Status',
      decision_reviews: 'Decision Reviews'
    }
  ).freeze

  def self.api_name
    DocHelpers.running_rake_task? ? ENV['API_NAME'].presence : DEFAULT_CONFIG_VALUES[:api_name]
  end

  def self.decision_reviews?
    DocHelpers.api_name == 'decision_reviews'
  end

  def self.running_rake_task?
    # SWAGGER_DRY_RUN is set in the appeals rake tasks: if it's not set, it means the spec is running as part of
    # a normal rspec suite instead.
    ENV['SWAGGER_DRY_RUN'].present?
  end

  def self.api_version
    DocHelpers.running_rake_task? ? ENV['API_VERSION'].presence : DEFAULT_CONFIG_VALUES[:api_version]
  end

  def self.doc_suffix
    ENV['RSWAG_ENV'] == 'dev' ? '_dev' : ''
  end
end
# rubocop:enable Metrics/ModuleLength
