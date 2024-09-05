# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MaintenanceWindows', type: :request do
  context 'with no upcoming windows' do
    it 'returns an empty list' do
      get '/v0/maintenance_windows'
      assert_response :success
      expect(JSON.parse(response.body)['data']).to eq([])
    end
  end

  context 'with upcoming window' do
    before do
      MaintenanceWindow.create(
        [
          {
            pagerduty_id: 'asdf1234',
            external_service: 'foo',
            start_time: Time.zone.now.yesterday,
            end_time: Time.zone.now.yesterday,
            description: 'maintenance from yesterday'
          },
          {
            pagerduty_id: 'asdf12345',
            external_service: 'foo',
            start_time: Time.zone.now.tomorrow,
            end_time: Time.zone.now.tomorrow,
            description: 'maintenance for tomorrow'
          }
        ]
      )
    end

    it 'returns only future maintenance windows' do
      get '/v0/maintenance_windows'
      assert_response :success
      expect(JSON.parse(response.body)['data'][0]['attributes']['description']).to eq('maintenance for tomorrow')
    end
  end
end
