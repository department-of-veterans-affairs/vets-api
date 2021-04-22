# frozen_string_literal: true

require 'rails_helper'

class FakeController < ApplicationController
  include AppealsApi::StatusSimulation
end

# rubocop:disable RSpec/PredicateMatcher
describe FakeController do
  describe '#status_simulation_reqested?' do
    it 'with simulation request headers' do
      request.headers['Status-Simulation'] = true

      expect(subject.status_simulation_reqested?).to be_truthy
    end

    it 'without simulation request headers' do
      expect(subject.status_simulation_reqested?).to be_falsey
    end
  end

  describe '#status_simulation_allowed?' do
    it 'not allowed in production' do
      with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
        with_settings(Settings, vsp_environment: 'production') do
          expect(subject.status_simulation_allowed?).to be_falsey
        end
      end
    end

    it 'is allowed in lower envs' do
      with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
        with_settings(Settings, vsp_environment: 'development') do
          expect(subject.status_simulation_allowed?).to be_truthy
        end

        with_settings(Settings, vsp_environment: 'staging') do
          expect(subject.status_simulation_allowed?).to be_truthy
        end

        with_settings(Settings, vsp_environment: 'sandbox') do
          expect(subject.status_simulation_allowed?).to be_truthy
        end
      end
    end
  end

  describe '#status_simulation_for' do
    it 'returns a wrapped object with a mocked status' do
      request.headers['Status-Simulation'] = 'something'

      expect(subject.status_simulation_for(Object.new).status).to eq('something')
    end
  end
end

# rubocop:enable RSpec/PredicateMatcher
