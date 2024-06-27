# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Metadata
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
          Metadata.new(
            obsolete:,
            decision_status:
          )
        end

        private

        def obsolete
          @data['secondaryStatus'] == 'Obsolete'
        end

        def decision_status
          @data['secondaryStatus'].presence_in(
            Decision::Statuses::ALL
          )
        end
      end
    end
  end
end
