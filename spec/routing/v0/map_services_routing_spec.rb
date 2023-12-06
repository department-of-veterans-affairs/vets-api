# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for MAP services', type: :routing do
  it 'routes token requests' do
    expect(
      post('/v0/map_services/foobar/token')
    ).to route_to('v0/map_services#token', application: 'foobar', format: 'json')
  end
end
