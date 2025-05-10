# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class DocumentsClient < TravelPay::BaseClient
    ##
    # HTTP GET call to the BTSSS 'claims/:id/documents' endpoint
    # API responds with array of documents related to the claim:
    #    "documentId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    #    "filename": "string",
    #    "mimetype": "string",
    #    "createdon": "2025-03-24T14:00:52.893Z"
    #
    # @return [TravelPay::DocumentSummary]
    #
    def get_document_ids(veis_token, btsss_token, claim_id)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('documents', 'get_document_ids') do
        connection(server_url: btsss_url).get("api/v2/claims/#{claim_id}/documents") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    ##
    # HTTP GET call to the BTSSS 'claims/:claimId/documents/:documentId' endpoint
    # API responds with the binary string of the document
    #
    # @return [TravelPay::DocumentBinary]
    #
    def get_document_binary(veis_token, btsss_token, params)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      params.symbolize_keys => { claim_id:, doc_id: }
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)
      log_to_statsd('documents', 'get_document_binary') do
        connection(server_url: btsss_url).get("api/v2/claims/#{claim_id}/documents/#{doc_id}") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end
  end
end
