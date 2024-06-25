# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Metadata <
      Data.define(
        :obsolete,
        :decision_status
      )

      class << self
        def find(id)
          Find.perform(id)
        end
      end
    end
  end
end
