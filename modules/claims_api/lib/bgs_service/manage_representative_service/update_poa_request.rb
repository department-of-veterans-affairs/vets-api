# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def update_poa_request(representative:, proc_id:)
      body =
        Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <data:POARequestUpdate>
            <VSOUserFirstName>#{representative.first_name}</VSOUserFirstName>
            <VSOUserLastName>#{representative.last_name}</VSOUserLastName>
            <dateRequestActioned>#{Time.current.iso8601}</dateRequestActioned>
            <procId>#{proc_id}</procId>

            <secondaryStatus>obsolete</secondaryStatus>
          </data:POARequestUpdate>
        EOXML

      make_request(
        endpoint:,
        action: 'updatePOARequest',
        body: body.to_s,
        key: 'POARequestUpdate'
      )
    end
  end
end
