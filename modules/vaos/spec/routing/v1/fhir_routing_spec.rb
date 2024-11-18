# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS FHIR routing configuration', skip: 'deprecated', type: :routing do
  it 'routes to the locations show' do
    expect(get('/vaos/v1/Location/123')).to route_to(
      format: :json,
      controller: 'vaos/v1/locations',
      action: 'show',
      id: '123'
    )
  end

  it 'routes to the organization show' do
    expect(get('/vaos/v1/Organization/123')).to route_to(
      format: :json,
      controller: 'vaos/v1/organizations',
      action: 'show',
      id: '123'
    )
  end

  it 'routes to the healthcare_services index' do
    query_string = '?organization.identifier=983&_include=HealthcareService%3Alocation'
    expect(get("/vaos/v1/HealthcareService#{query_string}")).to route_to(
      format: :json,
      controller: 'vaos/v1/healthcare_services',
      action: 'index',
      'organization.identifier' => '983',
      '_include' => 'HealthcareService:location'
    )
  end
end
