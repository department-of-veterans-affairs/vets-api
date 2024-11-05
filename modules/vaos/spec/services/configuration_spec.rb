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

    context 'when VAOS_DEBUG is set and not in production' do
      it 'sets up the connection with a stdout logger to display requests in curl format' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('VAOS_DEBUG').and_return('true')

        conn = VAOS::Configuration.instance.connection
        expect(conn.builder.handlers).to include(Faraday::Response::Logger)
        expect(conn.builder.handlers).to include(Faraday::Curl::Middleware)
      end
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
    it 'has a default timeout of 25 seconds' do
      expect(VAOS::Configuration.instance.read_timeout).to eq(25)
    end
  end
end
