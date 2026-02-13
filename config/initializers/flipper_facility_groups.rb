# frozen_string_literal: true

# Flipper groups for facility-based percentage rollouts.
#
# This initializer registers Flipper groups that combine two concepts:
#   1. Membership at a specific VA facility (by station ID)
#   2. A deterministic percentage gate using a CRC32 hash of the actor's flipper_id
#
# Usage:
#   1. Define your facility + percentage combos in FACILITY_PERCENTAGE_GROUPS below.
#   2. Enable the group on your feature flag:
#        Flipper.enable_group :my_feature, :facility_358_50pct
#   3. Check the feature as usual with an actor:
#        Flipper.enabled?(:my_feature, current_user)
#
# The percentage is deterministic — the same user always gets the same result,
# and it's evenly distributed across actors via CRC32 hashing.
#
# To roll out to 100% of a facility, set percentage to 100.
# To roll out to all facilities at a percentage, use the built-in
# Flipper.enable_percentage_of_actors instead.

require 'zlib'

# -------------------------------------------------------------------------
# Configuration: Define facility + percentage combos here.
# These are constants — defined once at load time, outside to_prepare.
#
# Each entry creates a Flipper group named: facility_<station_id>_<pct>pct
# e.g., { station_id: '358', percentage: 50 } => :facility_358_50pct
# -------------------------------------------------------------------------
FACILITY_PERCENTAGE_GROUPS = [
  # Examples — uncomment or add your own:
  # { station_id: '358', percentage: 25 },
  # { station_id: '358', percentage: 50 },
  # { station_id: '516', percentage: 100 },
].freeze

Rails.application.reloader.to_prepare do
  FACILITY_PERCENTAGE_GROUPS.each do |config|
    station_id = config[:station_id]
    percentage = config[:percentage]
    group_name = :"facility_#{station_id}_#{percentage}pct"

    next if Flipper.group_exists?(group_name)

    Flipper.register(group_name) do |actor, _context|
      next false unless actor.respond_to?(:flipper_id) && actor.respond_to?(:vha_facility_ids)

      # Gate 1: Is the user associated with this facility?
      facility_match = actor.vha_facility_ids.include?(station_id)

      # Gate 2: Deterministic percentage check, salted by station_id so each
      # facility gets an independent random distribution of users.
      within_percentage = Zlib.crc32("#{station_id}:#{actor.flipper_id}") % 100 < percentage

      facility_match && within_percentage
    end
  end
end
