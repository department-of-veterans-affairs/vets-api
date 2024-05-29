# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision <
      Data.define(
        :status,
        :representative,
        :declined_reason,
        :updated_at
      )

      module Statuses
        ALL = [
          NEW = 'New',
          PENDING = 'Pending',
          ACCEPTED = 'Accepted',
          DECLINED = 'Declined'
        ].freeze
      end

      class << self
        def find(id)
          Find.perform(id)
        end

        def create(id, decision)
          Create.perform(id, decision)
        end
      end

      Representative =
        Data.define(
          :first_name,
          :last_name,
          :email
        )
    end
  end
end
