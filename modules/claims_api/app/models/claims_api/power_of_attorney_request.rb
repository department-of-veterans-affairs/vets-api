# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest <
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

    Veteran =
      Data.define(
        :first_name,
        :middle_name,
        :last_name,
        :participant_id
      )

    Claimant =
      Data.define(
        :first_name,
        :last_name,
        :participant_id,
        :relationship_to_veteran
      )

    Address =
      Data.define(
        :city, :state, :zip, :country,
        :military_post_office,
        :military_postal_code
      )

    class << self
      def find(id)
        Find.perform(id)
      end

      def search(query)
        Search.perform(query)
      end
    end
  end
end
