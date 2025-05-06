# frozen_string_literal: true

module AccreditedRepresentativePortal
  module StagingSeeds
    module Constants
      RESOLUTION_HISTORY_CYCLE = %i[expiration decision].cycle

      RESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 30.days.ago
          loop do
            yielder << time
            time += 6.hours
          end
        end

      UNRESOLVED_TIME_TRAVELER =
        Enumerator.new do |yielder|
          time = 10.days.ago
          loop do
            yielder << time
            time += 6.hours
          end
        end
    end
  end
end
