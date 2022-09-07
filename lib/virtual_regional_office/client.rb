# frozen_string_literal: true

require 'virtual_regional_office/configuration'

module VirtualRegionalOffice
  class Client < Common::Client::Base
    include Common::Client::Concerns::Monitoring
    configuration VirtualRegionalOffice::Configuration

    # Initializes the MAS client.
    #
    # @example
    #
    # VirtualRegionalOffice::Client.new({
    #  "veteranIcn": "9000682",
    #  "diagnosticCode": "7101",
    #  "claimSubmissionId": "1234"
    # })
    def initialize(params)
      @veteran_icn = params[:veteran_icn]
      @diagnostic_code = params[:diagnostic_code]
      @claim_submission_id = params[:claim_submission_id]

      raise ArgumentError, 'no veteran_icn passed in for request.' if @veteran_icn.blank?
      raise ArgumentError, 'no diagnostic_code passed in for request.' if @diagnostic_code.blank?
      raise ArgumentError, 'no claim_submission_id passed in for request.' if @claim_submission_id.blank?
    end

    def assess_claim
      params = {
        veteranIcn: @veteran_icn,
        diagnosticCode: @diagnostic_code,
        claimSubmissionId: @claim_submission_id
      }

      perform(:post, Settings.virtual_regional_office.health_assessment_path, params.to_json.to_s, headers_hash)
    end

    private

    def headers_hash
      {
        'X-API-Key': Settings.virtual_regional_office.api_key
      }
    end
  end
end
