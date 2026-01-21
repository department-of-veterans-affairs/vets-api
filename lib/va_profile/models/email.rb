# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class Email < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable
      VALID_EMAIL_REGEX = /.+@.+\..+/i

      attribute :created_at, Vets::Type::ISO8601Time
      attribute :confirmation_date, Vets::Type::ISO8601Time
      attribute :email_address, String
      attribute :effective_end_date, Vets::Type::ISO8601Time
      attribute :effective_start_date, Vets::Type::ISO8601Time
      attribute :id, Integer
      attribute :source_date, Vets::Type::ISO8601Time
      attribute :source_system_user, String
      attribute :transaction_id, String
      attribute :updated_at, Vets::Type::ISO8601Time
      attribute :verification_date, Vets::Type::ISO8601Time
      attribute :vet360_id, String
      attribute :va_profile_id, String

      validates(
        :email_address,
        presence: true,
        format: { with: VALID_EMAIL_REGEX },
        length: { maximum: 255, minimum: 6 }
      )

      # Converts an instance of the Email model to a JSON encoded string suitable for use in
      # the body of a request to VAProfile
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      def in_json
        {
          bio: {
            emailAddressText: email_address,
            emailId: id,
            originatingSourceSystem: SOURCE_SYSTEM,
            sourceSystemUser: source_system_user,
            sourceDate: source_date,
            effectiveStartDate: effective_start_date,
            effectiveEndDate: effective_end_date,
            confirmationDate: confirmation_date,
            verificationDate: verification_date
          }
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the Email model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Email] the model built from the response body
      def self.build_from(body)
        VAProfile::Models::Email.new(
          created_at: body['create_date'],
          confirmation_date: body['confirmation_date'],
          email_address: body['email_address_text'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date'],
          id: body['email_id'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date'],
          verification_date: body['verification_date'],
          vet360_id: body['vet360_id'] || body['va_profile_id'],
          va_profile_id: body['va_profile_id'] || body['vet360_id']
        )
      end

      # Override the confirmation_date setter to correct it if it's after source_date.
      # This prevents issues where client-provided dates may be ahead due to time differences.
      # Uses the framework's type casting to ensure consistency with Vets::Type::ISO8601Time.
      # @param value [Time, String, nil] the confirmation date to set
      # @return [Time] the corrected confirmation date
      def confirmation_date=(value)
        @confirmation_date = Vets::Attributes::Value.cast(:confirmation_date, Vets::Type::ISO8601Time, value)
        correct_confirmation_date_if_needed
      end

      # Override the source_date setter to correct confirmation_date when source_date is set.
      # This handles the case where confirmation_date is set before source_date during initialization.
      # Uses the framework's type casting to ensure consistency with Vets::Type::ISO8601Time.
      # @param value [Time, String, nil] the source date to set
      # @return [Time] the source date
      def source_date=(value)
        @source_date = Vets::Attributes::Value.cast(:source_date, Vets::Type::ISO8601Time, value)
        correct_confirmation_date_if_needed
      end

      # Computed property for email verification status
      # @return [Boolean] true if verification_date is present and within the last year, false otherwise
      def contact_email_verified?
        return false if @verification_date.blank?

        @verification_date > 1.year.ago
      end

      private

      # Corrects confirmation_date if it's after source_date.
      # Both values are guaranteed to be Time objects (or nil) at this point.
      # @return [void]
      def correct_confirmation_date_if_needed
        return if @confirmation_date.blank? || @source_date.blank?

        @confirmation_date = @source_date if @confirmation_date > @source_date
      end
    end
  end
end
