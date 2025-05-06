# frozen_string_literal: true

require 'rails_helper'

describe Ccra::Configuration do
  subject { described_class.instance }

  before do
    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.api_url = 'http://test.example.com'
      ccra.base_path = 'api/v1'
      ccra.mock = false
    end
  end

  describe '#settings' do
    it 'returns CCRA settings from Settings.vaos.ccra' do
      expect(subject.settings).to eq(Settings.vaos.ccra)
    end
  end

  describe '#service_name' do
    it 'returns CCRA' do
      expect(subject.service_name).to eq('CCRA')
    end
  end

  describe '#mock_enabled?' do
    context 'when settings.mock is true' do
      before do
        Settings.vaos.ccra.mock = true
      end

      it 'returns true' do
        expect(subject.mock_enabled?).to be true
      end
    end

    context 'when settings.mock is false' do
      before do
        Settings.vaos.ccra.mock = false
      end

      it 'returns false' do
        expect(subject.mock_enabled?).to be false
      end
    end
  end

  describe '#connection' do
    let(:faraday_connection) { subject.connection }
    let(:handlers) { faraday_connection.builder.handlers }

    it 'returns a Faraday::Connection' do
      expect(faraday_connection).to be_a(Faraday::Connection)
    end

    it 'uses the correct base url' do
      expect(faraday_connection.url_prefix.to_s).to start_with('http://test.example.com')
    end

    it 'includes the expected middleware' do
      expect(handlers).to include(Faraday::Request::Json)
      expect(handlers).to include(Faraday::Response::Json)
    end

    context 'when VAOS_CCRA_DEBUG is set' do
      before do
        @original_debug = ENV.fetch('VAOS_CCRA_DEBUG', nil)
        ENV['VAOS_CCRA_DEBUG'] = 'true'
        allow(Rails.env).to receive(:production?).and_return(false)
      end

      after do
        ENV['VAOS_CCRA_DEBUG'] = @original_debug
      end

      it 'includes debug middleware' do
        handlers = subject.connection.builder.handlers
        expect(handlers).to include(Faraday::Curl::Middleware)
        expect(handlers).to include(Faraday::Response::Logger)
      end
    end

    context 'when VAOS_CCRA_DEBUG is not set' do
      before do
        @original_debug = ENV.fetch('VAOS_CCRA_DEBUG', nil)
        ENV['VAOS_CCRA_DEBUG'] = nil
      end

      after do
        ENV['VAOS_CCRA_DEBUG'] = @original_debug
      end

      it 'does not include debug middleware' do
        handlers = subject.connection.builder.handlers
        expect(handlers).not_to include(Faraday::Curl::Middleware)
        expect(handlers).not_to include(Faraday::Response::Logger)
      end
    end
  end

  describe 'delegated methods' do
    %i[api_url base_path].each do |method|
      it "delegates #{method} to settings" do
        expect(subject.settings).to receive(method)
        subject.public_send(method)
      end
    end
  end
end
