# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision <
      Data.define(
        :status,
        :declining_reason,
        :created_at,
        :created_by
      )

      module Statuses
        ALL = [
          ACCEPTING = 'accepting',
          DECLINING = 'declining'
        ].freeze
      end

      class << self
        def create(id, decision)
          Create.perform(id, decision)
        end

        def build(attrs)
          created_by =
            Representative.new(
              **attrs.delete(:created_by)
            )

          new(
            **attrs,
            # A bit weird. Because we're working with immutable value objects,
            # we don't have the opportunity to mutate only when creation
            # actually occurs.
            created_at: Time.current,
            created_by:
          )
        end
      end

      Representative =
        Data.define(
          :first_name,
          :last_name,
          :email
        )

      def accepting?
        status == Statuses::ACCEPTING
      end

      def declining?
        status == Statuses::DECLINING
      end
    end
  end
end
