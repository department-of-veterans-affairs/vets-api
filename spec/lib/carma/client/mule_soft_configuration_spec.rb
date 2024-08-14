# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_configuration'

describe CARMA::Client::MuleSoftConfiguration do
  subject { described_class.instance }

  describe 'id and secret' do
    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive_messages(client_id: fake_id, client_secret: fake_secret)
    end

    context 'have values' do
      subject { super().base_request_headers }

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
    subject { super().timeout }

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
    let(:host) { 'https://www.somesite.gov' }

    before do
      allow(Settings.form_10_10cg.carma.mulesoft).to receive(:host).and_return(host)
    end

    it 'returns the correct value' do
      expect(subject.send(:base_path)).to eq("#{host}/va-carma-caregiver-papi/api/")
    end
  end
end
