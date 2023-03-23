# frozen_string_literal: true

require 'savon'
require 'nokogiri'

module BGS
  class MockDisabilityRatingService
    def get_rating(current_user)
      options = {
        wsdl: "#{Settings.vet_verification.mock_bgs_url}/RatingServiceBean/RatingService/ratingRecord.wsdl",
        soap_header: header(current_user),
        endpoint: "#{Settings.vet_verification.mock_bgs_url}/RatingServiceBean/RatingService"
      }
      @client ||= Savon.client(options)
      response = nil
      begin
        response = request(:find_rating_data, fileNumber: current_user.ssn)
      rescue => e
        if e.message.include? 'PERSON_NOT_FOUND'
          handle_not_found_error!
        else
          throw e
        end
      end
      response.body[:find_rating_data_response][:return]
    end

    def header(current_user)
      # Stock XML structure {{{
      header = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
          <wsse:UsernameToken>
            <wsse:Username></wsse:Username>
          </wsse:UsernameToken>
          <vaws:VaServiceHeaders xmlns:vaws="http://vbawebservices.vba.va.gov/vawss">
            <vaws:CLIENT_MACHINE></vaws:CLIENT_MACHINE>
            <vaws:STN_ID></vaws:STN_ID>
            <vaws:applicationName></vaws:applicationName>
            <vaws:ExternalUid ></vaws:ExternalUid>
            <vaws:ExternalKey></vaws:ExternalKey>
          </vaws:VaServiceHeaders>
        </wsse:Security>
      EOXML
      # }}}

      { Username: Settings.bgs.client_username, CLIENT_MACHINE: Settings.bgs.client_ip,
        STN_ID: Settings.bgs.client_station_id, applicationName: Settings.bgs.application,
        ExternalUid: current_user.icn, ExternalKey: current_user.email }.each do |k, v|
        header.xpath(".//*[local-name()='#{k}']")[0].content = v
      end
      header
    end

    # Proxy to call a method on our web service.
    def request(method, message = nil)
      @client.call(method, message:)
    end

    # Handle BGS Person not found error
    def handle_not_found_error!
      raise Common::Exceptions::UnprocessableEntity.new(detail: 'Person Not Found')
    end
  end
end
