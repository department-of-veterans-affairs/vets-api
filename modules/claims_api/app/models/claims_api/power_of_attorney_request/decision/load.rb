# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Decision
      # Deserialization is inherently linked to a particular BGS service action,
      # as it maps from the representation for that action. For now, since only
      # one such mapping is needed, we showcase it in isolation here.
      class Load
        class << self
          def perform(data)
            new(data).perform
          end
        end

        def initialize(data)
          @data = data
        end

        def perform
          Decision.new(
            status:,
            declined_reason:,
            representative:,
            updated_at:
          )
        end

        private

        def status
          @data['secondaryStatus'].presence_in(
            Statuses::ALL
          )
        end

        def declined_reason
          return if status != Statuses::DECLINED

          @data['declinedReason']
        end

        def representative
          Representative.new(
            first_name: @data['VSOUserFirstName'],
            last_name: @data['VSOUserLastName'],
            email: @data['VSOUserEmail']
          )
        end

        def updated_at
          Utilities::Load.time(@data['dateRequestActioned'])
        end
      end
    end
  end
end
