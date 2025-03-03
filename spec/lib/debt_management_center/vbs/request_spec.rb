# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/vbs/request'

RSpec.describe DebtManagementCenter::VBS::Request do
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
      expect(subject.url).to eq('https://fwdproxy-staging.vfs.va.gov:4491')
    end
  end

  describe '.build' do
    it 'returns an instance of Request' do
      expect(subject).to be_an_instance_of(DebtManagementCenter::VBS::Request)
    end
  end

  describe '#mock_enabled?' do
    it 'default mock is false' do
      expect(subject.mock_enabled?).to be(true)
    end
  end

  describe '#headers' do
    it 'has request headers' do
      expect(subject.headers).to eq({ 'Host' => 'fwdproxy-staging.vfs.va.gov:4491',
                                      'Content-Type' => 'application/json',
                                      'apiKey' => 'abcd1234abcd1234abcd1234abcd1234abcd1234' })
    end
  end

  describe '#post' do
    let(:path) { '/foo/bar' }
    let(:params) { { foo: 'bar' } }
    let(:response) { Faraday::Response.new }

    it 'connection is called with post' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).with(path).and_return(response)

      expect_any_instance_of(Faraday::Connection).to receive(:post)
        .with(path).once

      subject.post(path, params)
    end
  end

  describe '#connection' do
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:conn) { Faraday.new { |b| b.adapter(:test, stubs) } }

    after do
      Faraday.default_connection = nil
    end

    it 'builds a Faraday HTTP connection' do
      allow(Faraday).to receive(:new).and_return(conn)

      expect(Faraday).to receive(:new).once

      subject.connection
    end
  end
end
