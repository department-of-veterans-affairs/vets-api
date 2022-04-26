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
    return '' unless ENV.fetch('RSWAG_ENV', '').length.positive?

    "_#{ENV['RSWAG_ENV']}"
  end
end
