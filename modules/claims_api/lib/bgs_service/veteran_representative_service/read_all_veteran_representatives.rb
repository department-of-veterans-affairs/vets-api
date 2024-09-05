# frozen_string_literal: true

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    # type_code: form type (I.E. 21-22 vs 21-22A)
    # ptcpnt_id: participant ID
    def read_all_veteran_representatives(type_code:, ptcpnt_id:)
      validate! type_code, ptcpnt_id

      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <ns0:CorpPtcpntIdFormTypeCode>
          <veteranCorpPtcpntId>#{ptcpnt_id}</veteranCorpPtcpntId>
          <formTypeCode>#{type_code}</formTypeCode>
        </ns0:CorpPtcpntIdFormTypeCode>
      EOXML
      ret = make_request(namespace: 'ns0', action: 'readAllVeteranRepresentatives', body:)
            &.dig('VeteranRepresentativeReturnList') || []
      [ret].flatten
    end

    def validate_read_all_veteran_representatives(type_code:, ptcpnt_id:)
      validate! type_code, ptcpnt_id
    rescue
      false
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
