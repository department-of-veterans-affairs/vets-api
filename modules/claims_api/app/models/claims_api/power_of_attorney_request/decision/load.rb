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
          return unless status.in?(
            Statuses::ALL
          )

          Decision.new(
            status:,
            declined_reason:,
            representative:,
            created_at:
          )
        end

        private

        def status
          @data['secondaryStatus']
        end

        def declined_reason
          # We won't make this scenario inbound, but maybe legacy data has this.
          return unless status == Statuses::DECLINED

          @data['declinedReason']
        end

        def representative
          Representative.new(
            first_name: @data['VSOUserFirstName'],
            last_name: @data['VSOUserLastName'],
            email: @data['VSOUserEmail']
          )
        end

        def created_at
          Utilities::Load.time(@data['dateRequestActioned'])
        end
      end
    end
  end
end
