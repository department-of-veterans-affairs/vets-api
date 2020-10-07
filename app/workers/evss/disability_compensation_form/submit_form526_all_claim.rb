# frozen_string_literal: true

require 'evss/disability_compensation_form/service'

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526AllClaim < EVSS::DisabilityCompensationForm::SubmitForm526
      # :nocov:
      def service(auth_headers)
        EVSS::DisabilityCompensationForm::Service.new(
          auth_headers
        )
      end
      # :nocov:
    end
  end
end
