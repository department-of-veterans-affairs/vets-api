# frozen_string_literal: true

module ClaimsApi
  class VdcVeteranRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      '/VDC/VeteranRepresentativeService'
    end

    def create_veteran_representative(ptcpnt_id, proc_id, form_type, poa_code)
      body = get_create_representative_body(ptcpnt_id, proc_id, form_type, poa_code)

      make_request(
        endpoint: bean_name,
        action: 'createVeteranRepresentative',
        body:,
        additional_namespace:
      )
    end

    private

    def additional_namespace
      ans = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        data
      EOXML
      ans.to_s
    end

    def get_create_representative_body(ptcpnt_id, proc_id, form_type, poa_code)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:VeteranRepresentative>
          <procId>#{proc_id}</procId>
          <formTypeCode>#{form_type}</formTypeCode>
          <poaCode>#{poa_code}</poa_code>
          <section7332Auth>false</section7332Auth>
          <limitationDrugAbuse>false</limitationDrugAbuse>
          <limitationAlcohol>false</limitationAlcohol>
          <limitationHIV>false</limitationHIV>
          <limitationSCA>false</limitationSCA>
          <vdcStatus>This</vdcStatus>
          <representativeType></representativeType>
          <changeAddressAuth>false</changeAddressAuth>
          <veteranPtcpntId>#{ptcpnt_id}</veteranPtcpntId>
        </data:VeteranRepresentative>
      EOXML
    end
  end
end