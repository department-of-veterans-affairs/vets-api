# frozen_string_literal: true

module ClaimsApi
  class VdcManageRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      'VDC/ManageRepresentativeService'
    end

    def update_poa
      body = get_update_poa_body
      make_request(
        endpoint: bean_name,
        action: 'updatePOARequest',
        body:,
        additional_namespace:
      )
    end

    private

    def additional_namespace
      Nokogiri::XML::DocumentFragment.parse <<~EOXML
        xmlns:data='http://gov.va.vba.benefits.vdc/data'
      EOXML
    end

    def get_update_poa_body
      # TEMP VALUES
      rep_first_name = 'Tamara'
      rep_last_name = 'Ellis'
      proc_id = '3854457'
      # END TEMP VALUES
      current_date = Time.zone.now.strftime('%Y-%m-%dT%H:%M:%SZ')

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:POARequestUpdate>
          <VSOUserFirstName>#{rep_first_name}</VSOUserFirstName>
          <VSOUserLastName>#{rep_last_name}</VSOUserLastName>
          <dateRequestActioned>#{current_date}</dateRequestActioned>
          <procId>#{proc_id}</procId>

          <secondaryStatus>obsolete</secondaryStatus>
        </data:POARequestUpdate>
      EOXML
      body.to_s
    end
  end
end
