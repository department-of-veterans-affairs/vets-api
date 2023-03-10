# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_configuration'

describe CARMA::Client::MuleSoftConfiguration do
  describe 'id and secret' do
    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:client_id).and_return(fake_id)
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:client_secret).and_return(fake_secret)
    end

    context 'have values' do
      subject { described_class.instance.base_request_headers }

      let(:fake_id) { 'BEEFCAFE1234' }
      let(:fake_secret) { 'C0FFEEFACE4321' }

      describe '#base_request_headers' do
        it 'contains the configured values' do
          expect(subject[:client_id]).to eq(fake_id)
          expect(subject[:client_secret]).to eq(fake_secret)
        end
      end
    end
  end

  describe 'timeout' do
    subject { described_class.instance.timeout }

    context 'has a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft).to receive(:timeout).and_return(23)
      end

      it 'returns the configured value' do
        expect(subject).to eq(23)
      end
    end

    context 'does not have a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft).to receive(:key?).and_return(nil)
      end

      it 'returns the default value' do
        expect(subject).to eq(10)
      end
    end
  end

  describe 'base_path' do
    subject { described_class.instance }

    let(:host) { 'https://www.somesite.gov' }

    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:host).and_return(host)
    end

    it 'returns the correct value' do
      expect(subject.send(:base_path)).to eq("#{host}/va-carma-caregiver-papi/api/")
    end
  end
end
