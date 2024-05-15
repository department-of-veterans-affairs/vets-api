# frozen_string_literal: true

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def update_poa_request(representative:, proc_id:)
      first_name = representative.try(:first_name) || representative[:first_name]
      last_name = representative.try(:last_name) || representative[:last_name]

      body =
        Nokogiri::XML::DocumentFragment.parse <<~EOXML
          <data:POARequestUpdate>
            <VSOUserFirstName>#{first_name}</VSOUserFirstName>
            <VSOUserLastName>#{last_name}</VSOUserLastName>
            <dateRequestActioned>#{Time.current.iso8601}</dateRequestActioned>
            <procId>#{proc_id}</procId>

            <secondaryStatus>obsolete</secondaryStatus>
          </data:POARequestUpdate>
        EOXML

      make_request(
        action: 'updatePOARequest',
        body: body.to_s,
        key: 'POARequestUpdate'
      )
    end
  end
end
