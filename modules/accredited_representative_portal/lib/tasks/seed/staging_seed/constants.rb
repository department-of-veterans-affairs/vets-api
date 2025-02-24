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

      # Maps representative IDs to their email indices
      REP_EMAIL_MAP = {
        '57045' => 0,
        '32820' => 1,
        '53182' => 2,
        '53532' => 3,
        '52923' => 4,
        '29280' => 5,
        '7869' => 6,
        '52735' => 7,
        '52167' => 8,
        '21461' => 9,
        '56092' => 10,
        '53112' => 11,
        '54766' => 12,
        '46996' => 13,
        '57243' => 14,
        '57631' => 15,
        '5179' => 16,
        '54652' => 17,
        '55520' => 18,
        '47219' => 19
      }.freeze
    end
  end
end
