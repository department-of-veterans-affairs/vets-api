# frozen_string_literal: true

require 'evss/disability_compensation_form/service_increase_only'

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
