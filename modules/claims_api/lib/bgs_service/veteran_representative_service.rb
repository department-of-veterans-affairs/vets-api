# frozen_string_literal: true

require_relative 'veteran_representative_service/create_veteran_representative_request'
require_relative 'veteran_representative_service/read_all_veteran_representatives'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      'VDC/VeteranRepresentativeService'
    end

    def read_all_veteran_representatives(**options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOML
        <data:CorpPtcpntIdFormTypeCode>
          <FORM_TYPE_CODE>#{options[:form_type_code]}</FORM_TYPE_CODE>
          <VETERAN_CORP_PTCPNT_ID>#{options[:participant_id]}</VETERAN_CORP_PTCPNT_ID>
        </data:CorpPtcpntIdFormTypeCode>
      EOML

      make_request(endpoint: bean_name, body:, action: 'readAllVeteranRepresentatives', key: 'return')
    end
  end
end
