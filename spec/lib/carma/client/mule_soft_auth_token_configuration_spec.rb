# frozen_string_literal: true

require 'rails_helper'
require 'carma/client/mule_soft_auth_token_configuration'

describe CARMA::Client::MuleSoftAuthTokenConfiguration do
  subject { described_class.instance }

  let(:auth_token_url) { 'https://www.somesite.gov' }

  before do
    allow(Settings.form_10_10cg.carma.mulesoft.v2).to receive(:auth_token_url).and_return(auth_token_url)
  end

  describe 'connection' do
    subject { super().connection }

    it 'sets url previx' do
      expect(subject.url_prefix.to_s).to eq("#{auth_token_url}/oauth2/default/v1/token")
    end
  end

  describe 'service_name' do
    subject { super().service_name }

    it 'returns class name' do
      expect(subject).to eq('CARMA::Client::MuleSoftAuthTokenConfiguration')
    end
  end

  describe 'timeout' do
    subject { super().timeout }

    context 'has a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.v2).to receive(:timeout).and_return(23)
      end

      it 'returns the configured value' do
        expect(subject).to eq(23)
      end
    end

    context 'does not have a configured value' do
      before do
        allow(Settings.form_10_10cg.carma.mulesoft.v2).to receive(:key?).and_return(nil)
      end

      it 'returns the default value' do
        expect(subject).to eq(10)
      end
    end
  end

  describe 'base_path' do
    subject { super().send(:base_path) }

    it 'returns the correct value' do
      expect(subject).to eq("#{auth_token_url}/oauth2/default/v1/token")
    end
  end
end
