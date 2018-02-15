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
    context 'when Settings.appeals.mock is true' do
      before { Settings.appeals.mock = 'true' }
      it 'returns true' do
        expect(Appeals::Configuration.instance.mock_enabled?).to be_truthy
      end
    end

    context 'when Settings.appeals.mock is false' do
      before { Settings.appeals.mock = 'false' }
      it 'returns false' do
        expect(Appeals::Configuration.instance.mock_enabled?).to be_falsey
      end
    end
  end
end
