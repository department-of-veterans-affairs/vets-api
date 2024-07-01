# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Summary <
      Data.define(
        :id,
        :power_of_attorney_code,
        :veteran,
        :claimant,
        :claimant_address,
        :decision,
        :authorizes_address_changing,
        :authorizes_treatment_disclosure,
        :created_at
      )

      class << self
        def search(query)
          Search.perform(query)
        end
      end

      Veteran =
        Data.define(
          :first_name,
          :middle_name,
          :last_name
        )

      Claimant =
        Data.define(
          :first_name,
          :last_name,
          :relationship_to_veteran
        )

      Address =
        Data.define(
          :city, :state, :zip, :country,
          :military_post_office,
          :military_postal_code
        )
    end
  end
end
