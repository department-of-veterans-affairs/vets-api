# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MedicalCopays::Request do
  subject { described_class.build }

  describe 'attributes' do
    it 'responds to settings' do
      expect(subject.respond_to?(:settings)).to be(true)
    end
  end

  describe 'settings' do
    it 'has a host' do
      expect(subject.host).to eq('fwdproxy-staging.vfs.va.gov:4491')
    end

    it 'has base_path' do
      expect(subject.base_path).to eq('/vbsapi')
    end

    it 'has service_name' do
      expect(subject.service_name).to eq('VBS')
    end

    it 'has a url' do
      url = 'https://fwdproxy-staging.vfs.va.gov:4491'
      expect(subject.url).to eq(url)
    end
  end

  describe '.build' do
    it 'returns an instance of Request' do
      expect(subject).to be_an_instance_of(MedicalCopays::Request)
    end
  end

  describe '#mock_enabled?' do
    it 'default mock is false' do
      expect(subject.mock_enabled?).to be(true)
    end
  end

  describe '#headers' do
    it 'has request headers' do
      host = 'fwdproxy-staging.vfs.va.gov:4491'
      expect(subject.headers).to eq({ 'Host' => host,
                                      'Content-Type' => 'application/json',
                                      'apiKey' => 'abcd1234abcd1234abcd1234abcd1234abcd1234' })
    end
  end

  describe '#post' do
    let(:path) { '/foo/bar' }
    let(:params) { { edipi: '123', vistaAccountNumbers: [1234] } }
    let(:response) { Faraday::Response.new }

    it 'connection is called with post' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_return(response)

      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with(path).once

      subject.post(path, params)
    end

    context 'with debt_copay_logging Flipper enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_copay_logging).and_return(true)
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it 'calls the with_monitoring_and_error_handling method' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:with_monitoring_and_error_handling)
        # rubocop:enable RSpec/SubjectStub
        subject.post(path, params)
      end

      it 'logs the error message' do
        allow_any_instance_of(Faraday::Connection)
          .to receive(:post).with(path).and_raise(StandardError.new('Something went wrong'))
        expect(Rails.logger).to receive(:error).with(
          'MedicalCopays::Request error: Something went wrong'
        )

        expect do
          subject.post(path, params)
        end.to raise_error(StandardError, 'Something went wrong')
      end
    end

    context 'with debt_copay_logging Flipper not enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_copay_logging).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      it 'calls the with_monitoring_and_error_handling method' do
        # rubocop:disable RSpec/SubjectStub
        expect(subject).to receive(:with_monitoring)
        # rubocop:enable RSpec/SubjectStub
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_return(response)
        subject.post(path, params)
      end
    end
  end

  describe '#get' do
    let(:path) { '/foo/bar/:statement_id' }
    let(:response) { Faraday::Response.new }

    it 'connection is called with get' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).with(path).and_return(response)

      expect_any_instance_of(Faraday::Connection).to receive(:get)
        .with(path).once

      subject.get(path)
    end
  end

  describe '#connection' do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:conn) { Faraday.new { |b| b.adapter(:test, stubs) } }

    after do
      Faraday.default_connection = nil
    end

    it 'bla' do
      allow(Faraday).to receive(:new).and_return(conn)

      expect(Faraday).to receive(:new).once

      subject.connection
    end
  end
end
