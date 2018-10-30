# frozen_string_literal: true

module EVSS
  module DisabilityCompensationForm
    class SubmitForm526IncreaseOnly < EVSS::DisabilityCompensationForm::SubmitForm526
      # :nocov:
      def service(auth_headers)
        EVSS::DisabilityCompensationForm::ServiceIncreaseOnly.new(
          auth_headers
        )
      end
      # :nocov:
    end
  end
end
