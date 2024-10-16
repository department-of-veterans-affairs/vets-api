# frozen_string_literal: true

require 'virtual_regional_office/configuration'

module VirtualRegionalOffice
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration VirtualRegionalOffice::Configuration

    STATSD_KEY_PREFIX = 'api.vro'

    def classify_vagov_contentions(params)
      with_monitoring do
        perform(:post, Settings.virtual_regional_office.vagov_classification_path, params.to_json.to_s, headers_hash)
      end
    end

    def get_max_rating_for_diagnostic_codes(diagnostic_codes_array)
      with_monitoring do
        params = { diagnostic_codes: diagnostic_codes_array }
        perform(:post, Settings.virtual_regional_office.max_cfi_path, params.to_json.to_s, headers_hash)
      end
    end

    def merge_end_products(pending_claim_id:, ep400_id:)
      with_monitoring do
        params = { pending_claim_id: pending_claim_id.to_i, ep400_claim_id: ep400_id.to_i }
        perform(:post, Settings.virtual_regional_office.ep_merge_path, params.to_json.to_s, headers_hash)
      end
    end

    def generate_summary(claim_submission_id:, diagnostic_code:, veteran_info:, evidence:)
      params = {
        claimSubmissionId: claim_submission_id,
        diagnosticCode: diagnostic_code,
        veteranInfo: veteran_info,
        evidence:
      }

      perform(:post, Settings.virtual_regional_office.evidence_pdf_path, params.to_json.to_s, headers_hash)
    end

    def download_summary(claim_submission_id:)
      path = "#{Settings.virtual_regional_office.evidence_pdf_path}/#{claim_submission_id}"
      perform(:get, path, {}, headers_hash.merge(Accept: 'application/pdf'))
    end

    # Tiny middleware to replace the configuration option `faraday.response :json` with behavior
    # that only decodes JSON for application/json responses. This allows us to handle non-JSON
    # responses (e.g. application/pdf) without loss of convenience.
    def perform(method, path, params, headers = nil, options = nil)
      result = super
      result.body = JSON.parse(result.body) if result.response_headers['content-type'] == 'application/json'
      result
    end

    private

    def headers_hash
      {
        'X-API-Key': Settings.virtual_regional_office.api_key
      }
    end
  end
end
