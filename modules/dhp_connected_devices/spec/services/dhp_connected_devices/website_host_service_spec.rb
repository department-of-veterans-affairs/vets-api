# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebsiteHostService, type: :service do # written as a class
  subject { described_class.new }

  describe 'website_host_service#get_redirect_url' do
    let(:vendor) { 'fitbit' }
    let(:environment) { nil }

    before do
      allow(Settings).to receive(:vsp_environment).and_return(environment)
    end

    context 'when environment is localhost' do
      let(:environment) { 'localhost' }

      it 'redirects to localhost:3001' do
        redirect_url = subject.get_redirect_url({ status: 'status', vendor: })

        expect(redirect_url).to eq 'http://localhost:3001/health-care/connected-devices/?fitbit=status#_=_'
      end
    end

    context 'when environment is dev' do
      let(:environment) { 'development' }

      it 'redirects to dev.va.gov' do
        redirect_url = subject.get_redirect_url({ status: 'status', vendor: })

        expect(redirect_url).to eq 'https://dev.va.gov/health-care/connected-devices/?fitbit=status#_=_'
      end
    end

    context 'when environment is staging' do
      let(:environment) { 'staging' }

      it 'redirects to staging.va.gov' do
        redirect_url = subject.get_redirect_url({ status: 'status', vendor: })

        expect(redirect_url).to eq 'https://staging.va.gov/health-care/connected-devices/?fitbit=status#_=_'
      end
    end

    context 'when environment is sandbox' do
      let(:environment) { 'sandbox' }

      it 'redirects to dev.va.gov' do
        redirect_url = subject.get_redirect_url({ status: 'status', vendor: })

        expect(redirect_url).to eq 'https://dev.va.gov/health-care/connected-devices/?fitbit=status#_=_'
      end
    end

    context 'when environment is production' do
      let(:environment) { 'production' }

      it 'redirects to va.gov' do
        redirect_url = subject.get_redirect_url({ status: 'status', vendor: })

        expect(redirect_url).to eq 'https://www.va.gov/health-care/connected-devices/?fitbit=status#_=_'
      end
    end
  end
end
