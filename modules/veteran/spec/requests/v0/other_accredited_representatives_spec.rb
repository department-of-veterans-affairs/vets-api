# frozen_string_literal: true

require 'rails_helper'
require_relative 'base_accredited_representatives_shared_spec'
require_relative 'other_accredited_representatives_shared_spec'

RSpec.describe 'Veteran::V0::OtherAccreditedRepresentatives', type: :request do
  let(:path) { '/services/veteran/v0/other_accredited_representatives' }

  before do
    create(:representative, representative_id: '123', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            long: -77.050552, lat: 38.820450, location: 'POINT(-77.050552 38.820450)',
                            first_name: 'Bob', last_name: 'Law') # ~6 miles from Washington, D.C.

    create(:representative, representative_id: '234', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            long: -77.436649, lat: 39.101481, location: 'POINT(-77.436649 39.101481)',
                            first_name: 'Eliseo', last_name: 'Schroeder') # ~25 miles from Washington, D.C.

    create(:representative, representative_id: '345', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            long: -76.609383, lat: 39.299236, location: 'POINT(-76.609383 39.299236)',
                            first_name: 'Marci', last_name: 'Weissnat') # ~35 miles from Washington, D.C.

    create(:representative, representative_id: '456', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            long: -77.466316, lat: 38.309875, location: 'POINT(-77.466316 38.309875)',
                            first_name: 'Gerard', last_name: 'Ortiz') # ~47 miles from Washington, D.C.

    create(:representative, representative_id: '567', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            long: -76.3483, lat: 39.5359, location: 'POINT(-76.3483 39.5359)',
                            first_name: 'Adriane', last_name: 'Crona') # ~57 miles from Washington, D.C.
    create(:representative, representative_id: '935', poa_codes: ['A12'], user_types: %w[attorney claim_agents],
                            first_name: 'No', last_name: 'Location') # no location
  end

  include_examples 'base_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'attorney'

  include_examples 'base_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'claim_agents'

  include_examples 'other_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'attorney'

  include_examples 'other_accredited_representatives_controller_shared_examples',
                   '/services/veteran/v0/other_accredited_representatives', 'claim_agents'
end
