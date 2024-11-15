# frozen_string_literal: true

module ClaimsApi
  class VetRecordService < ClaimsApi::LocalBGS
    def bean_name
      'VetRecordServiceBean/VetRecordWebService'
    end

    def update_birls_record(**options)
      poa_code_two = options[:poa_code].is_a?(Array) ? options[:poa_code][1] : '00'
      body = Nokogiri::XML::DocumentFragment.parse <<~EOML
        <birlsUpdateInput>
          <CLAIM_NUMBER>#{options[:file_number]}</CLAIM_NUMBER>
          <SOC_SEC_NUM>#{options[:ssn]}</SOC_SEC_NUM>
          <POWER_OF_ATTY_CODE1>#{options[:poa_code]}</POWER_OF_ATTY_CODE1>
          <POWER_OF_ATTY_CODE2>#{poa_code_two}</POWER_OF_ATTY_CODE2>
          <PAYEE_NUMBER>'00'</PAYEE_NUMBER>
        </birlsUpdateInput>
      EOML

      make_request(endpoint: bean_name, body:, action: 'updateBirlsRecord', key: 'return')
    end
  end
end
