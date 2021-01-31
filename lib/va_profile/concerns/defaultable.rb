# frozen_string_literal: true

module VAProfile
  module Concerns
    module Defaultable
      extend ActiveSupport::Concern

      # Sets the included default values
      #
      # @param user [User] The user associated with the transaction
      # @return [VAProfile::Models::Base] A VAProfile::Models::Base instance, be it Email, Address, etc.
      #
      def set_defaults(user)
        now = Time.zone.now.iso8601

        tap do |record|
          record.attributes = {
            effective_start_date: now,
            source_date: now,
            vet360_id: user.vet360_id,
            source_system_user: user.icn
          }
        end
      end
    end
  end
end
