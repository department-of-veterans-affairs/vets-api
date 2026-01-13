# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Concerns::EVSSDeprecation, type: :controller do
  controller(ApplicationController) do
    include V0::Concerns::EVSSDeprecation

    def index
      response_data = { 'data' => ['test'], 'meta' => { 'existing' => 'value' } }
      response_data = add_deprecation_metadata(response_data)
      render json: response_data
    end
  end

  let(:user) { build(:user) }

  before do
    sign_in_as(user)
  end

  describe 'deprecation warnings' do
    it 'adds deprecation headers to response' do
      get :index

      expect(response.headers['Deprecation']).to eq('date="2026-01-28"')
      expect(response.headers['Sunset']).to eq('2026-01-28')
      expect(response.headers['Link']).to include('/v0/benefits_claims')
      expect(response.headers['Warning']).to include('EVSS Claims API is deprecated')
    end

    it 'adds deprecation metadata to response body' do
      get :index

      json_response = JSON.parse(response.body)
      expect(json_response['meta']['deprecation']).to be_present
      expect(json_response['meta']['deprecation']['deprecated']).to be(true)
      expect(json_response['meta']['deprecation']['sunset_date']).to eq('2026-01-28')
      expect(json_response['meta']['deprecation']['replacement_endpoint']).to eq('/v0/benefits_claims')
      expect(json_response['meta']['deprecation']['message']).to include('deprecated')
    end

    it 'preserves existing meta fields' do
      get :index

      json_response = JSON.parse(response.body)
      expect(json_response['meta']['existing']).to eq('value')
      expect(json_response['meta']['deprecation']).to be_present
    end

    it 'logs deprecation warning' do
      expect(Rails.logger).to receive(:warn).with(
        'EVSS endpoint accessed - service will be deprecated',
        hash_including(
          message_type: 'evss.deprecation_warning',
          sunset_date: '2026-01-28'
        )
      )

      get :index
    end

    it 'increments StatsD metric' do
      expect(StatsD).to receive(:increment).with(
        'api.evss.deprecation_warning',
        tags: array_including('service:evss')
      )

      get :index
    end

    it 'calculates days until sunset' do
      travel_to Time.zone.parse('2026-01-15') do
        get :index

        json_response = JSON.parse(response.body)
        expect(json_response['meta']['deprecation']['days_remaining']).to eq(13)
      end
    end
  end
end
