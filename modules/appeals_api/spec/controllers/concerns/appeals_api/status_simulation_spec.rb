# frozen_string_literal: true

require 'rails_helper'

class FakeController < ApplicationController
  include AppealsApi::StatusSimulation
end

class AppealTypeModel
  STATUSES = %w[default_status other_status].freeze

  def status
    'default_status'
  end
end

# rubocop:disable RSpec/PredicateMatcher RSpec/PendingWithoutReason
describe FakeController do
  describe '#status_simulation_requested?' do
    xit 'with simulation request headers' do
      request.headers['Status-Simulation'] = true

      expect(subject.status_simulation_requested?).to be_truthy
    end

    xit 'without simulation request headers' do
      expect(subject.status_simulation_requested?).to be_falsey
    end
  end

  describe '#status_simulation_allowed?' do
    xit 'not allowed in production' do
      with_settings(Settings.modules_appeals_api, status_simulation_enabled: true) do
        with_settings(Settings, vsp_environment: 'production') do
          expect(subject.status_simulation_allowed?).to be_falsey
        end
      end
    end

    xit 'is allowed in lower envs' do
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

  describe '#with_status_simulation' do
    describe 'only allows mocking valid statuses' do
      xit 'valid status' do
        request.headers['Status-Simulation'] = 'other_status'

        expect(subject.with_status_simulation(AppealTypeModel.new).status).to eq('other_status')
      end

      xit 'invalid status' do
        request.headers['Status-Simulation'] = 'invalid_status'

        expect(subject.with_status_simulation(AppealTypeModel.new).status).to eq('default_status')
      end
    end
  end
end
# rubocop:enable RSpec/PredicateMatcher
