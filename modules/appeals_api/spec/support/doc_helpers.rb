# frozen_string_literal: true

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

  # @param [Hash] opts
  # @option opts [String] :desc The description of the test. Required.
  # @option opts [Symbol] :response_wrapper Method name to wrap the response, to modify the output of the example
  # @option opts [Boolean] :extract_desc Whether to use the example name
  # @option opts [Boolean] :skip_match Whether to skip the match metadata assertion
  shared_examples 'rswag example' do |opts|
    before do |example|
      submit_request(example.metadata)
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

  def self.wip_doc_enabled?(sym, require_env_slug = false) # rubocop:disable Style/OptionalBooleanParameter
    # Only block doc generation if we still flag it as a WIP
    return true unless Settings.modules_appeals_api.documentation.wip_docs&.include?(sym.to_s)

    return false if ENV['WIP_DOCS_ENABLED'].nil?

    enabled_docs = ENV['WIP_DOCS_ENABLED'].split(',').map(&:to_sym)
    return false if enabled_docs.blank?

    if require_env_slug
      enabled_docs.include?(sym) && ENV.key?('RSWAG_SECTION_SLUG')
    else
      enabled_docs.include?(sym)
    end
  end

  def wip_doc_enabled?(sym)
    DocHelpers.wip_doc_enabled?(sym)
  end

  def self.doc_suffix
    section = ENV['RSWAG_SECTION_SLUG']
    env = ENV['RSWAG_ENV']

    parts = []
    parts << section unless section.nil?
    parts << env unless env.nil?

    parts.empty? ? '' : "_#{parts.join('_')}"
  end

  DOC_SECTION_TITLES = {
    hlr: 'Higher-Level Reviews',
    nod: 'Notice of Disagreements',
    sc: 'Supplemental Claims',
    contestable_issues: 'Contestable Issues',
    legacy_appeals: 'Legacy Appeals'
  }.freeze

  DOC_SECTION_PATHS = {
    hlr: '/services/appeals/higher_level_reviews/{version}',
    nod: '/services/appeals/notice_of_disagreements/{version}',
    sc: '/services/appeals/supplemental_claims/{version}',
    contestable_issues: '/services/appeals/contestable_issues/{version}',
    legacy_appeals: '/services/appeals/legacy_appeals/{version}'
  }.freeze

  def self.doc_title
    DOC_SECTION_TITLES[ENV.fetch('RSWAG_SECTION_SLUG', '').to_sym] || 'Decision Reviews'
  end

  def self.doc_tags
    if (section_slug = ENV['RSWAG_SECTION_SLUG'])
      [{ name: DOC_SECTION_TITLES[section_slug.to_sym], description: '' }]
    else
      DOC_SECTION_TITLES.values.collect { |title| { name: title, description: '' } }
    end
  end

  def self.doc_basepath(version = nil)
    path_template = '/services/appeals/{version}/decision_reviews'
    if wip_doc_enabled?(:segmented_apis)
      path_template = DOC_SECTION_PATHS.fetch(ENV['RSWAG_SECTION_SLUG']&.to_sym, path_template)
    end

    return path_template if version.nil?

    path_template.gsub('{version}', version)
  end
end
