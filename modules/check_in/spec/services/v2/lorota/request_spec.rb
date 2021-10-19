# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::Request do
  subject { described_class }

  describe '.build' do
    it 'returns an instance of Request' do
      expect(subject.build).to be_an_instance_of(V2::Lorota::Request)
    end
  end

  describe '#get' do
    let(:req) { Faraday::Request.new }

    it 'connection is called with get' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(anything).and_return(anything)

      expect_any_instance_of(Faraday::Connection).to receive(:get)
        .with('/dev/data/d602d9eb-9a31-484f-9637-13ab0b507e0d').once.and_yield(req)

      subject.build.get('/dev/data/d602d9eb-9a31-484f-9637-13ab0b507e0d')
    end
  end

  describe '#post' do
    let(:req) { Faraday::Request.new }

    it 'connection is called with post' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(anything)

      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with('/dev/token').once.and_yield(req)

      subject.build.post('/dev/token', {})
    end
  end

  describe '#connection' do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:conn) { Faraday.new { |b| b.adapter(:test, stubs) } }

    after do
      Faraday.default_connection = nil
    end

    it 'creates a new instance just once' do
      allow(Faraday).to receive(:new).and_return(conn)

      expect(Faraday).to receive(:new).once

      subject.build.connection
    end
  end

  describe '#headers' do
    it 'has default headers' do
      hsh = {
        'Content-Type' => 'application/json',
        'x-api-key' => 'Xc7k35oE2H9aDeUEpeGa38PzAHyLT9jb5HiKeBfs',
        'x-apigw-api-id' => '22t00c6f97'
      }

      expect(subject.build.headers).to eq(hsh)
    end
  end

  describe '#settings' do
    it 'has a url' do
      url = 'https://vpce-06399548ef94bdb41-lk4qp2nd.execute-api.us-gov-west-1.vpce.amazonaws.com'

      expect(subject.build.url).to eq(url)
    end

    it 'has a service_name' do
      expect(subject.build.service_name).to eq('LoROTA-API')
    end

    it 'has an api_id' do
      expect(subject.build.api_id).to eq('22t00c6f97')
    end

    it 'has an api_key' do
      expect(subject.build.api_key).to eq('Xc7k35oE2H9aDeUEpeGa38PzAHyLT9jb5HiKeBfs')
    end
  end
end
