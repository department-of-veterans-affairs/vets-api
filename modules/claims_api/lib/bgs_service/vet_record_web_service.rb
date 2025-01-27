# frozen_string_literal: true

module ClaimsApi
  class VetRecordWebService < ClaimsApi::LocalBGS
    def bean_name
      'VetRecordServiceBean/VetRecordWebService'
    end

    def update_birls_record(**options)
      poa_code = options[:poa_code]
      body = Nokogiri::XML::DocumentFragment.parse <<~EOML
        <birlsUpdateInput>
          <CLAIM_NUMBER>#{options[:file_number]}</CLAIM_NUMBER>
          <SOC_SEC_NUM>#{options[:ssn]}</SOC_SEC_NUM>
          <POWER_OF_ATTY_CODE1>#{poa_code[0]}</POWER_OF_ATTY_CODE1>
          <POWER_OF_ATTY_CODE2>#{poa_code[1]}#{poa_code[2]}</POWER_OF_ATTY_CODE2>
          <PAYEE_NUMBER>00</PAYEE_NUMBER>
        </birlsUpdateInput>
      EOML

      make_request(endpoint: bean_name, body:, action: 'updateBirlsRecord', key: 'return')
    end
  end
end
