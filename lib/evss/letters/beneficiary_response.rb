# frozen_string_literal: true
require 'common/client/concerns/service_status'

module EVSS
  module Letters
    class BeneficiaryResponse < EVSS::Response
      attribute :body, EVSS::Letters::Beneficiary
    end
  end
end
