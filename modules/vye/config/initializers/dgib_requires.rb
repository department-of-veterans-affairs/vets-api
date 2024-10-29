# frozen_string_literal: true

# Zeitwerk was giving me fits until I added this.
# It's a little ugly, but it works.
require Rails.root.join('modules', 'vye', 'lib', 'dgib', 'claimant_lookup', 'service')
require Rails.root.join('modules', 'vye', 'lib', 'dgib', 'claimant_status', 'service')
require Rails.root.join('modules', 'vye', 'lib', 'dgib', 'verification_record', 'service')
require Rails.root.join('modules', 'vye', 'lib', 'dgib', 'verify_claimant', 'service')
