# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    # Deserialization is inherently linked to a particular BGS service action,
    # as it maps from the representation for that action. For now, since only
    # one such mapping is needed, we showcase it in isolation here.
    class Load
      class << self
        def perform(participant_id, data)
          new(participant_id, data).perform
        end
      end

      def initialize(participant_id, data)
        @participant_id = participant_id
        @data = data
      end

      def perform
        PowerOfAttorneyRequest.new(
          power_of_attorney_code:,
          veteran:,
          obsolete:,
          decision_status:
        )
      end

      private

      def power_of_attorney_code
        @data['poaCode']
      end

      def veteran
        Veteran.new(
          participant_id: @participant_id,
          file_number: @data['veteranVAFileNumber'],
          ssn: @data['veteranSSN']
        )
      end

      def obsolete
        @data['secondaryStatus'] == 'Obsolete'
      end

      def decision_status
        case @data['secondaryStatus']
        when 'Accepted'
          Decision::Statuses::ACCEPTING
        when 'Declined'
          Decision::Statuses::DECLINING
        end
      end
    end
  end
end
