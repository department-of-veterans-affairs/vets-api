# frozen_string_literal: true

module ClaimsApi
  class VetRecordService < ClaimsApi::LocalBGS
    def bean_name
      'VetRecordServiceBean/VetRecordWebService'
    end

    def update_birls_record(**options)
      builder = Nokogiri::XML::Builder.new(
        birlsUpdateInput do
          CLAIM_NUMBER options[:file_number] if options[:file_number]
          SOC_SEC_NUM options[:ssn] if options[:ssn]
          POWER_OF_ATTY_CODE1 options[:poa_code][0] if options[:poa_code][0]
          POWER_OF_ATTY_CODE2 options[:poa_code][1] if options[:poa_code][1]
        end
      )
      body = builder_to_xml(builder)
      make_request(endpoint: bean_name, body:, action: 'updateBirlsRecord', key: 'return')
      # 'update_birls_record_response'
    end
  end
end
