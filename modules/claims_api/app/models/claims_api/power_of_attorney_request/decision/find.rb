# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision
      # TODO: Separate error handling from POA request find?
      module Find
        class << self
          def perform(id)
            poa_request = PowerOfAttorneyRequest.find(id)
            poa_request.decision
          end
        end
      end
    end
  end
end
