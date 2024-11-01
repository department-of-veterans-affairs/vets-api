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

      response = make_request(endpoint: bean_name, action: 'findAssignedFlashes', body:)
      response.body[:find_assigned_flashes_response][:return]
    end

    def add_flash(options = {})
      # builder = Nokogiri::XML::Builder.new do
      #   addFlash do
      #     FileNumber options[:file_number]
      #     # flash do
      #     # assignedIndicator options[:assigned_indicator]
      #     # flashName options[:flash_name]
      #     # flashType options[:flash_type]
      #     # end
      #   end
      # end
      # body = builder_to_xml(builder)

      # injected = convert_nil_values(options)
      # body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
      #   <ser:addFlash>
      #     #{injected}
      #   </ser:addFlash>
      # EOXML
      body =
        "<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:ser='http://services.share.benefits.vba.va.gov/'>
          <soapenv:Header/>
          <soapenv:Body>
              <ser:addFlash>
                <fileNumber>#{options[:file_number]}</fileNumber>
                <flash>
                    <assignedIndicator>?</assignedIndicator>
                    <flashName>?</flashName>
                    <flashType>?</flashType>
                </flash>
              </ser:addFlash>
          </soapenv:Body>
        </soapenv:Envelope>"

      response = make_request(endpoint: bean_name, action: 'addFlash', body:)
      # namespaces: 'ser')
      # , namespaces: { ser: addFlash }
      response.body[:add_flash_response]
    end
  end
end
