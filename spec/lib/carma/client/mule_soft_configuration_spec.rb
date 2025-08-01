# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_configuration'

describe CARMA::Client::MuleSoftConfiguration do
  subject { described_class.instance }

  let(:host) { 'https://www.somesite.gov' }

  describe 'connection' do
    let(:faraday) { double('Faraday::Connection', options: double('Faraday::Options')) }

    it 'creates a new Faraday connection with the correct base path' do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:host).and_return(host)
      expect(Faraday).to receive(:new).with("#{host}/va-carma-caregiver-papi/api/")
      subject.connection
    end

    it 'creates the connection' do
      allow(Faraday).to receive(:new).and_yield(faraday)
      allow(faraday.options).to receive(:timeout=)

      expect(faraday).to receive(:use).once.with(:breakers, { service_name: subject.service_name })
      expect(faraday).to receive(:request).once.with(:instrumentation,
                                                     { name: 'CARMA::Client::MuleSoftConfiguration' })
      expect(faraday).to receive(:adapter).once.with(Faraday.default_adapter)
      expect(faraday.options).to receive(:timeout=).once.with(subject.timeout)

      subject.connection
    end
  end

  it 'returns class name as service_name' do
    expect(subject.service_name).to eq('CARMA::Client::MuleSoftConfiguration')
  end

  describe 'timeout' do
    let(:timeout) { subject.timeout }

    context 'has a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft).to receive(:timeout).and_return(23)
      end

      it 'returns the configured value' do
        expect(timeout).to eq(23)
      end
    end

    context 'does not have a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft).to receive(:key?).and_return(nil)
      end

      it 'returns the default value' do
        expect(timeout).to eq(600)
      end
    end
  end

  describe 'settings' do
    let(:expected_settings) { 'my_fake_settings_value' }

    before do
      allow(Settings.form_10_10cg.carma).to receive(:mulesoft).and_return(expected_settings)
    end

    it 'returns expected settings path' do
      expect(subject.settings).to eq(expected_settings)
    end
  end

  describe 'base_path' do
    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:host).and_return(host)
    end

    it 'returns the correct value' do
      expect(subject.send(:base_path)).to eq("#{host}/va-carma-caregiver-papi/api/")
    end
  end
end
