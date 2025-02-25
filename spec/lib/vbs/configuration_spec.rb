# frozen_string_literal: true

require 'rails_helper'
require 'vbs/configuration'

describe VBS::Configuration do
  def subject
    described_class.instance
  end

  describe '#service_name' do
    it 'is "VBS"' do
      expect(subject.service_name).to eq('VBS')
    end
  end

  describe '#mock_enabled?' do
    it 'is false' do
      expect(subject.mock_enabled?).to be(false)
    end
  end

  describe '#base_path' do
    before do
      expect(Settings).to receive(:vbs).and_return(
        double(url: :VBS_HOST_AND_URL)
      )
    end

    it 'returns the value for Settings.vbs.url' do
      expect(subject.base_path).to eq(:VBS_HOST_AND_URL)
    end
  end

  describe '#connection' do
    it 'instantiates a Faraday client' do
      connection = subject.connection
      expect(connection).to be_instance_of(Faraday::Connection)
      expect(connection.adapter).to eq(Faraday::Adapter::NetHttp)
      expect(connection.builder.handlers).to eq(
        [
          Faraday::Request::Json,
          Faraday::Response::Json
        ]
      )

      expect(connection.headers).to eq(
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => 'Vets.gov Agent'
        }
      )

      expect(connection.options.timeout).to eq(15)
      expect(connection.options.open_timeout).to eq(15)
      expect(connection.url_prefix.to_s).to eq(subject.base_path)
    end
  end
end
