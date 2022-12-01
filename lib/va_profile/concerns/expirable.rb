# frozen_string_literal: true

module VAProfile
  module Concerns
    module Expirable
      extend ActiveSupport::Concern

      included do
        validate :effective_end_date_has_passed
      end

      private

      # Raises validation error if the model's effective_end_date is past
      #
      # @param user [User] The user associated with the transaction
      # @return [VAProfile::Models::Base] A VAProfile::Models::Base instance, be it Email, Address, etc.
      #
      def effective_end_date_has_passed
        if effective_end_date.present? && (effective_end_date > Time.zone.now)
          errors.add(:effective_end_date, 'must be in the past')
        end
      end
    end
  end
end
