# frozen_string_literal: true

module ClaimsApi
  class VdcManageRepresentativeService < ClaimsApi::LocalBGS

    def manage_representative_service
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:POARequestUpdate>
          <!--Optional:-->
          <VSOUserEmail>?</VSOUserEmail>
          <VSOUserFirstName>?</VSOUserFirstName>
          <VSOUserLastName>?</VSOUserLastName>
          <dateRequestActioned>?</dateRequestActioned>
          <!--Optional:-->
          <declinedReason>?</declinedReason>
          <procId>?</procId>
          <secondaryStatus>?</secondaryStatus>
        </data:POARequestUpdate>
      EOXML

      make_request(
        endpoint: 'VDC/ManageRepresentativeService', 
        action: 'updatePOARequest', 
        body:
      )
    end
  end
end