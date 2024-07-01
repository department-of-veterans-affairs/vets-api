# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest <
    Data.define(
      :power_of_attorney_code,
      :veteran,
      :obsolete,
      :decision_status
    )

    class << self
      def find(id)
        Find.perform(id)
      end
    end

    Veteran =
      Data.define(
        :participant_id,
        :file_number,
        :ssn
      )
  end
end
