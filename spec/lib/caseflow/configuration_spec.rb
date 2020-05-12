# frozen_string_literal: true

require 'rails_helper'
require 'mvi/service'

describe Caseflow::Configuration do
  describe '#app_token' do
    it 'has an app token' do
      expect(Caseflow::Configuration.instance.app_token).to eq(Settings.caseflow.app_token)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(Caseflow::Configuration.instance.service_name).to eq('CaseflowStatus')
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.caseflow.mock is true' do
      before { Settings.caseflow.mock = 'true' }

      it 'returns true' do
        expect(Caseflow::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.caseflow.mock is false' do
      before { Settings.caseflow.mock = 'false' }

      it 'returns false' do
        expect(Caseflow::Configuration.instance).not_to be_mock_enabled
      end
    end
  end
end
