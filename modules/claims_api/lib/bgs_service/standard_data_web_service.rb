# frozen_string_literal: true

module ClaimsApi
  class StandardDataWebService < ClaimsApi::LocalBGS
    def bean_name
      'StandardDataWebServiceBean/StandardDataWebService'
    end

    def find_poas
      make_request(endpoint: bean_name, action: 'findPOAs', body: nil, key: 'PowerOfAttorneyDTO')
    end
  end
end
