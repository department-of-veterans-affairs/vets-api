# frozen_string_literal: true

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    # rubocop:disable Metrics/MethodLength
    def create_veteran_representative(ptcpnt_id:, proc_id:, form_type:, poa_code:)
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

      make_request(
        endpoint:,
        action: 'createVeteranRepresentative',
        body: body.to_s,
        key: 'VeteranRepresentative'
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
