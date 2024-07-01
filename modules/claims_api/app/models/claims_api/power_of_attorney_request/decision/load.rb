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
          return if status.blank?

          Decision.new(
            status:,
            declining_reason:,
            created_at:,
            created_by:
          )
        end

        private

        def status
          case @data['secondaryStatus']
          when 'Accepted'
            Statuses::ACCEPTING
          when 'Declined'
            Statuses::DECLINING
          end
        end

        def declining_reason
          # We won't make this scenario inbound, but maybe legacy data has this.
          return unless status == Statuses::DECLINING

          @data['declinedReason']
        end

        def created_by
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
