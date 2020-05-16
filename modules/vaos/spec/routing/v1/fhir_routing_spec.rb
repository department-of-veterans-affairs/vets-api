# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VAOS FHIR routing configuration', type: :routing do
  it 'routes to the locations index' do
    expect(get('/vaos/v1/Location')).to route_to(
      format: :json,
      controller: 'vaos/v1/locations',
      action: 'index'
    )
  end

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
end
