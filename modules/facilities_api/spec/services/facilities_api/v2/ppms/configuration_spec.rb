# frozen_string_literal: true

require 'rails_helper'

describe FacilitiesApi::V2::PPMS::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(FacilitiesApi::V2::PPMS::Configuration.instance.service_name).to eq('PPMS')
    end
  end

  describe '#connection' do
    it 'returns a connection' do
      expect(FacilitiesApi::V2::PPMS::Configuration.instance.connection).not_to be_nil
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.ppms.mock is nil' do
      before { allow(Settings.ppms).to receive(:mock).and_return(nil) }

      it 'returns false' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).not_to be_mock_enabled
      end
    end

    context 'when Settings.ppms.mock is false' do
      before { allow(Settings.ppms).to receive(:mock).and_return(false) }

      it 'returns false' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).not_to be_mock_enabled
      end
    end

    context 'when Settings.ppms.mock is "false" (string)' do
      before { allow(Settings.ppms).to receive(:mock).and_return('false') }

      it 'returns false' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).not_to be_mock_enabled
      end
    end

    context 'when Settings.ppms.mock is true' do
      before { allow(Settings.ppms).to receive(:mock).and_return(true) }

      it 'returns true' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.ppms.mock is "true" (string)' do
      before { allow(Settings.ppms).to receive(:mock).and_return('true') }

      it 'returns true' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.ppms.mock is 1 (integer from env)' do
      before { allow(Settings.ppms).to receive(:mock).and_return(1) }

      it 'returns true' do
        expect(FacilitiesApi::V2::PPMS::Configuration.instance).to be_mock_enabled
      end
    end
  end
end
