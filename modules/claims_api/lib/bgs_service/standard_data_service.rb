# frozen_string_literal: true

module ClaimsApi
  class StandardDataService < ClaimsApi::LocalBGS
    def bean_name
      'StandardDataService/StandardDataService'
    end

    def get_contention_classification_type_code_list
      body = Nokogiri::XML::DocumentFragment.parse <<~EOXML
        <getContentionClassificationTypeCodeList/>
      EOXML

      response = make_request(endpoint: bean_name, action: 'getContentionClassificationTypeCodeList', body:)
      response[:return]
    end
  end
end
