# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS routing configuration', type: :routing do
  it 'routes to the appointments index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/appointments')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointments',
      action: 'index'
    )
  end

  it 'routes to the appointments create' do
    skip 'VAOS V0 routes disabled'
    expect(post('/vaos/v0/appointments')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointments',
      action: 'create'
    )
  end

  it 'routes to the appointments cancel' do
    skip 'VAOS V0 routes disabled'
    expect(put('/vaos/v0/appointments/cancel')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointments',
      action: 'cancel'
    )
  end

  it 'routes to the appointments show' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/appointments/va/12345')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointments',
      action: 'show',
      id: '12345',
      type: 'va'
    )
  end

  it 'routes to the appointments show fails when not va' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/appointments/xx/12345')).to route_to(
      controller: 'application',
      action: 'routing_error',
      path: 'vaos/v0/appointments/xx/12345'
    )
  end

  it 'routes to the appointment requests index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/appointment_requests')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointment_requests',
      action: 'index'
    )
  end

  it 'routes to the appointment requests create' do
    skip 'VAOS V0 routes disabled'
    expect(post('/vaos/v0/appointment_requests')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointment_requests',
      action: 'create'
    )
  end

  it 'routes to the appointment requests update (cancel)' do
    skip 'VAOS V0 routes disabled'
    expect(put('/vaos/v0/appointment_requests/123')).to route_to(
      format: :json,
      controller: 'vaos/v0/appointment_requests',
      action: 'update',
      id: '123'
    )
  end

  it 'routes to the appointment requests messages index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/appointment_requests/123/messages')).to route_to(
      format: :json,
      controller: 'vaos/v0/messages',
      action: 'index',
      appointment_request_id: '123'
    )
  end

  it 'routes to the appointment requests messages create' do
    skip 'VAOS V0 routes disabled'
    expect(post('/vaos/v0/appointment_requests/123/messages')).to route_to(
      format: :json,
      controller: 'vaos/v0/messages',
      action: 'create',
      appointment_request_id: '123'
    )
  end

  it 'routes to the community care eligibilty endpoint' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/community_care/eligibility/PrimaryCare')).to route_to(
      format: :json,
      controller: 'vaos/v0/cc_eligibility',
      action: 'show',
      service_type: 'PrimaryCare'
    )
  end

  it 'routes to the community care supported_sites endpoint' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/community_care/supported_sites')).to route_to(
      format: :json,
      controller: 'vaos/v0/cc_supported_sites',
      action: 'index'
    )
  end

  it 'routes to the systems index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/systems')).to route_to(
      format: :json,
      controller: 'vaos/v0/systems',
      action: 'index'
    )
  end

  it 'routes to the systems direct_scheduling_facilities index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/systems/983/direct_scheduling_facilities')).to route_to(
      format: :json,
      controller: 'vaos/v0/direct_scheduling_facilities',
      action: 'index',
      system_id: '983'
    )
  end

  it 'routes to the systems pact index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/systems/983/pact')).to route_to(
      format: :json,
      controller: 'vaos/v0/pact',
      action: 'index',
      system_id: '983'
    )
  end

  it 'routes to the systems clinic_institutions index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/systems/983/clinic_institutions')).to route_to(
      format: :json,
      controller: 'vaos/v0/clinic_institutions',
      action: 'index',
      system_id: '983'
    )
  end

  it 'routes to the facilities index action' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities')).to route_to(
      format: :json,
      controller: 'vaos/v0/facilities',
      action: 'index'
    )
  end

  it 'routes to the facility clinics index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities/123/clinics')).to route_to(
      format: :json,
      controller: 'vaos/v0/clinics',
      action: 'index',
      facility_id: '123'
    )
  end

  it 'routes to the facility cancel_reasons index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities/123/cancel_reasons')).to route_to(
      format: :json,
      controller: 'vaos/v0/cancel_reasons',
      action: 'index',
      facility_id: '123'
    )
  end

  it 'routes to the facility available appointments index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities/123/available_appointments')).to route_to(
      format: :json,
      controller: 'vaos/v0/available_appointments',
      action: 'index',
      facility_id: '123'
    )
  end

  it 'routes to the facility limits index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities/123/limits')).to route_to(
      format: :json,
      controller: 'vaos/v0/limits',
      action: 'index',
      facility_id: '123'
    )
  end

  it 'routes to the facility visits (pact) index' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/facilities/688/visits/direct')).to route_to(
      format: :json,
      controller: 'vaos/v0/visits',
      action: 'index',
      facility_id: '688',
      schedule_type: 'direct'
    )
  end

  it 'routes to the preferences show action' do
    skip 'VAOS V0 routes disabled'
    expect(get('/vaos/v0/preferences')).to route_to(
      format: :json,
      controller: 'vaos/v0/preferences',
      action: 'show'
    )
  end

  it 'routes to the preferences update action' do
    skip 'VAOS V0 routes disabled'
    expect(put('/vaos/v0/preferences')).to route_to(
      format: :json,
      controller: 'vaos/v0/preferences',
      action: 'update'
    )
  end
end
