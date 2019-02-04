# frozen_string_literal: true

module BGS
  def self.poa_finder
    Rails.logger.info '-----'
    headers = {}
    headers['Host'] = 'https://internal-dsva-vagov-dev-fwdproxy-1893365470.us-gov-west-1.elb.amazonaws.com:4447'
    @client ||= Savon.client(
      wsdl: 'https://internal-dsva-vagov-dev-fwdproxy-1893365470.us-gov-west-1.elb.amazonaws.com:4447/OrgWebServiceBean/OrgWebService?WSDL',
      soap_header: header,
      log: true,
      headers: headers,
      open_timeout: 600, # in seconds
      read_timeout: 600, # in seconds
      convert_request_keys_to: :none,
      pretty_print_xml: true,
      log_level: :debug,
      logger: Rails.logger
    )
    Rails.logger.info @client.inspect
    Rails.logger.info @client.operations.inspect
  end

  def self.header
    # Stock XML structure {{{
    header = Nokogiri::XML::DocumentFragment.parse <<-HEADER
  <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
    <wsse:UsernameToken>
      <wsse:Username></wsse:Username>
    </wsse:UsernameToken>
    <vaws:VaServiceHeaders xmlns:vaws="http://vbawebservices.vba.va.gov/vawss">
      <vaws:CLIENT_MACHINE></vaws:CLIENT_MACHINE>
      <vaws:STN_ID></vaws:STN_ID>
      <vaws:applicationName></vaws:applicationName>
    </vaws:VaServiceHeaders>
  </wsse:Security>
    HEADER
    # }}}

    { Username: 'VAgovAPI', CLIENT_MACHINE: '172.30.2.135',
      STN_ID: '281', applicationName: 'VAgovAPI' }.each do |k, v|
      header.xpath(".//*[local-name()='#{k}']")[0].content = v
    end
    header
  end
end
