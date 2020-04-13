# from spec/routing/session_routing_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Session', type: :routing do
  it 'routes to the appointment requests index' do
    expect(get('/v0/vaos/appointment_requests')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointment_requests',
      action: 'index'
    )
  end

  it 'routes to the appointments index' do
    expect(get('/v0/vaos/appointments')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointments',
      action: 'index'
    )
  end

  it 'routes to the facility available appointments index' do
    expect(get('/v0/vaos/facilities/123/available_appointments')).to route_to(
      format: :json,
      controller: 'vaos/v0/available_appointments',
      action: 'index',
      facility_id: '123'
    )
  end

  it 'routes to the pact endpoint' do
    expect(get('/v0/vaos/facilities/688/visits/direct')).to route_to(
      format: :json,
      controller: 'vaos/v0/visits',
      action: 'index',
      facility_id: '688',
      schedule_type: 'direct'
    )
  end

  it 'routes to the community care eligibilty endpoint' do
    expect(get('/v0/vaos/community_care/eligibility/PrimaryCare')).to route_to(
      format: :json,
      controller: 'vaos/v0/cc_eligibility',
      action: 'show',
      service_type: 'PrimaryCare'
    )
  end

  it 'routes to the systems index' do
    expect(get('/v0/vaos/systems')).to route_to(
      format: :json,
      controller: 'vaos/v0/systems',
      action: 'index'
    )
  end
end
