# frozen_string_literal: true

require 'rails_helper'

describe Eps::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(Eps::Configuration.instance.service_name).to eq('EPS')
    end
  end

  describe '#connection' do
    it 'returns a connection' do
      expect(Eps::Configuration.instance.connection).not_to be_nil
    end

    context 'when VAOS_DEBUG is set and not in production' do
      it 'sets up the connection with a stdout logger to display requests in curl format' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('VAOS_EPS_DEBUG').and_return('true')
        allow(Rails.env).to receive(:production?).and_return(false)

        conn = Eps::Configuration.instance.connection
        expect(conn.builder.handlers).to include(Faraday::Response::Logger)
        expect(conn.builder.handlers).to include(Faraday::Curl::Middleware)
      end
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.vaos.eps.mock is true' do
      before { allow(Settings.vaos.eps).to receive(:mock).and_return(true) }

      it 'returns true' do
        expect(Eps::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.vaos.eps.mock is false' do
      before { allow(Settings.vaos.eps).to receive(:mock).and_return(false) }

      it 'returns false' do
        expect(Eps::Configuration.instance).not_to be_mock_enabled
      end
    end
  end

  describe '#settings' do
    it 'returns the settings' do
      expect(Eps::Configuration.instance.settings).to eq(Settings.vaos.eps)
    end
  end
end
