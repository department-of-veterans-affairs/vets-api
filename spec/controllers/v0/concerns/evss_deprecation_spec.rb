# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::Concerns::EVSSDeprecation, type: :controller do
  controller(ApplicationController) do
    include V0::Concerns::EVSSDeprecation

    def index
      render json: { 'data' => ['test'], 'meta' => { 'existing' => 'value' } }
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

    it 'logs deprecation warning' do
      expect(Rails.logger).to receive(:warn).with(
        'EVSS endpoint accessed - service will be deprecated',
        hash_including(
          message_type: 'evss.deprecation_warning',
          sunset_date: '2026-01-28',
          days_until_sunset: be_an(Integer)
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
  end
end
