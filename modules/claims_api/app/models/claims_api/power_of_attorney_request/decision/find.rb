# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision
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
