# frozen_string_literal: true

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      'VDC/VeteranRepresentativeService'
    end

    def create_veteran_representative(options)
      injected = convert_nil_values(options)

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:VeteranRepresentative>
          #{injected}
        </data:VeteranRepresentative>
      EOXML

      make_request(
        endpoint: bean_name,
        namespaces: { 'data' => '/data' },
        action: 'createVeteranRepresentative',
        body: body.to_s,
        key: 'VeteranRepresentativeReturn',
        transform_response: false
      )
    end

    # type_code: form type (I.E. 21-22 vs 21-22A)
    # ptcpnt_id: participant ID
    def read_all_veteran_representatives(type_code:, ptcpnt_id:)
      validate! type_code, ptcpnt_id

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <data:CorpPtcpntIdFormTypeCode>
          <veteranCorpPtcpntId>#{ptcpnt_id}</veteranCorpPtcpntId>
          <formTypeCode>#{type_code}</formTypeCode>
        </data:CorpPtcpntIdFormTypeCode>
      EOXML

      ret = make_request(endpoint: bean_name, namespaces: { 'data' => '/data' },
                         action: 'readAllVeteranRepresentatives', body:,
                         key: 'VeteranRepresentativeReturnList',
                         transform_response: false) || []

      [ret].flatten
    end

    private

    def validate!(type_code, ptcpnt_id)
      errors = []
      errors << 'type_code is required' if type_code.nil?
      errors << 'ptcpnt_id must be 1-15 digits and > 0' if ptcpnt_id.length > 15 || ptcpnt_id.to_i < 1

      raise ArgumentError, "Errors: #{errors.join(', ')}" if errors.any?
    end
  end
end
