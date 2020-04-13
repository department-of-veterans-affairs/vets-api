# from spec/routing/session_routing_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Session', type: :routing do
  it 'routes to the pact endpoint' do
    expect(get('/v0/vaos/facilities/688/visits/direct')).to route_to(
      format: :json,
      controller: 'vaos/visits',
      action: 'index',
      facility_id: '688',
      schedule_type: 'direct'
    )
  end

  it 'routes to the community care eligibilty endpoint' do
    expect(get('/v0/vaos/community_care/eligibility/PrimaryCare')).to route_to(
      format: :json,
      controller: 'vaos/cc_eligibility',
      action: 'show',
      service_type: 'PrimaryCare'
    )
  end
end
