# frozen_string_literal: true

module ClaimsApi
  class ClaimantService < ClaimsApi::LocalBGS
    def bean_name
      'ClaimantServiceBean/ClaimantWebService'
    end

    def find_assigned_flashes(file_number)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <fileNumber />
      EOXML

      { fileNumber: file_number }.each do |k, v|
        body.xpath("./*[local-name()='#{k}']")[0].content = v
      end

      make_request(endpoint: bean_name, action: 'findAssignedFlashes', body:, key: 'return')
    end

    def add_flash(file_number:, flash: {})
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <fileNumber>#{file_number}</fileNumber>
        <flash>
          <assignedIndicator>#{flash[:assigned_indicator]}</assignedIndicator>
          <flashName>#{flash[:flash_name]}</flashName>
          <flashType>#{flash[:flash_type]}</flashType>
        </flash>
      EOXML

      response = make_request(endpoint: bean_name, action: 'addFlash', body:)
      response&.dig(:body, :add_flash_response) || response
    end
  end
end
