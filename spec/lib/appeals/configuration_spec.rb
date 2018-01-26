# frozen_string_literal: true

require 'rails_helper'
require 'mvi/service'

describe Appeals::Configuration do
  describe '#app_token' do
    it 'has an app token' do
      expect(Appeals::Configuration.instance.app_token).to eq(Settings.appeals_status.app_token)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(Appeals::Configuration.instance.service_name).to eq('AppealsStatus')
    end
  end

  describe '#mock_enabled?' do
    it 'has a mock_enabled? method that returns a boolean' do
      expect(Appeals::Configuration.instance.mock_enabled?).to be_in([true, false])
    end
  end
end
