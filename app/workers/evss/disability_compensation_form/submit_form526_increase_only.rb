# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526IncreaseOnly < EVSS::DisabilityCompensationForm::SubmitForm526
      def service(auth_headers)
        EVSS::DisabilityCompensationForm::ServiceIncreaseOnly.new(
          auth_headers
        )
      end
    end
  end
end
