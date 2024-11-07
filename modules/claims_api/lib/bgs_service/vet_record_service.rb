# frozen_string_literal: true

module ClaimsApi
  class VetRecordService < ClaimsApi::LocalBGS
    def bean_name
      'VetRecordServiceBean/VetRecordWebService'
    end

    def update_birls_record(**options)
      body = Nokogiri::XML::DocumentFragment.parse <<~EOML
        <birlsUpdateInput>
          <CLAIM_NUMBER>#{options[:file_number][:file_nbr]}</CLAIM_NUMBER>
          <SOC_SEC_NUM>#{options[:ssn]}</SOC_SEC_NUM>
          <POWER_OF_ATTY_CODE1>#{options[:poa_code]}</POWER_OF_ATTY_CODE1>
          <PAYEE_NUMBER>?</PAYEE_NUMBER>
        </birlsUpdateInput>
      EOML

      make_request(endpoint: bean_name, body:, action: 'updateBirlsRecord', key: 'return')
      # 'update_birls_record_response'
    end
  end
end
