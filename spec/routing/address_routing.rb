# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes for Address', type: :routing do
  before(:all) { @cached_enabled_val = Settings.evss.reference_data_service.enabled }
  after(:all) do
    # leave the routes in the expected state for future specs
    Settings.evss.reference_data_service.enabled = @cached_enabled_val
    Rails.application.reload_routes!
  end

  context '#reference_data_service.enabled=true' do
    before do
      Settings.evss.reference_data_service.enabled = true
      Rails.application.reload_routes!
    end

    it 'routes to rds' do
      expect(get('/v0/address/countries')).to route_to(
        controller: 'v0/addresses',
        action: 'rds_countries',
        format: 'json'
      )
    end
  end

  context '#reference_data_service.enabled=false' do
    before do
      Settings.evss.reference_data_service.enabled = false
      Rails.application.reload_routes!
    end

    it 'does not route to rds' do
      expect(get('/v0/address/countries')).to route_to(
        controller: 'v0/addresses',
        action: 'countries',
        format: 'json'
      )
    end
  end
end
