# frozen_string_literal: true

require 'rails_helper'

describe VAOS::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(VAOS::Configuration.instance.service_name).to eq('VAOS')
    end
  end

  describe '#connection' do
    it 'returns a connection' do
      expect(VAOS::Configuration.instance.connection).not_to be_nil
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.va_mobile.mock is true' do
      before { allow(Settings.va_mobile).to receive(:mock).and_return(true) }

      it 'returns true' do
        expect(VAOS::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.va_mobile.mock is false' do
      before { allow(Settings.va_mobile).to receive(:mock).and_return(false) }

      it 'returns false' do
        expect(VAOS::Configuration.instance).not_to be_mock_enabled
      end
    end
  end

  describe '#read_timeout' do
    it 'has a default timeout of 55 seconds' do
      expect(VAOS::Configuration.instance.read_timeout).to eq(55)
    end
  end
end
