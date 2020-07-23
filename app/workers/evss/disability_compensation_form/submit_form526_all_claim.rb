# frozen_string_literal: true

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
