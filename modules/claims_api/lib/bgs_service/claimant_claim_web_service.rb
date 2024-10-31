# frozen_string_literal: true

module ClaimsApi
  class ClaimantWebService < ClaimsApi::LocalBGS
    def bean_name
      'ClaimantWebServiceBean/ClaimantWebService'
    end

    def add_flash(options)
      response = request(
        :add_flash,
        {
          fileNumber: options[:file_number],
          flash: {
            assignedIndicator: options[:assigned_indicator],
            flashName: options[:flash_name],
            flashType: options[:flash_type]
          }
        },
        options[:file_number]
      )
      response.body[:add_flash_response]

      builder = Nokogiri::XML::Builder.new do
        bnftClaimId claim_id
      end

      body = builder_to_xml(builder)

      make_request(endpoint: bean_name, action: 'findBnftClaim', body:)
    end
  end
end
