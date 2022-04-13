# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WebsiteHostService, type: :service do # written as a class
  subject { described_class.new }

  describe 'website_host_service#get_redirect_url' do
    old_value = Settings.vsp_environment
    vendor = 'fitbit'
    after do
      # cleanup Settings mock
      allow(Settings).to receive(:vsp_environment).and_call_original
      expect(Settings.vsp_environment).to eq(old_value)
    end

    it 'nil redirects to localhost:3001' do
      allow(Settings).to receive(:vsp_environment).and_return(nil)
      redirect_url = subject.get_redirect_url({ status: 'status', vendor: vendor })

      expect(redirect_url).to eq 'http://localhost:3001/health-care/connected-devices/?fitbit=status#_=_'
    end

    it 'dev redirects to dev.va.gov' do
      allow(Settings).to receive(:vsp_environment).and_return('development')
      redirect_url = subject.get_redirect_url({ status: 'status', vendor: vendor })

      expect(redirect_url).to eq 'https://dev.va.gov/health-care/connected-devices/?fitbit=status#_=_'
    end

    it 'staging redirects to staging.va.gov' do
      allow(Settings).to receive(:vsp_environment).and_return('staging')
      redirect_url = subject.get_redirect_url({ status: 'status', vendor: vendor })

      expect(redirect_url).to eq 'https://staging.va.gov/health-care/connected-devices/?fitbit=status#_=_'
    end

    it 'sandbox redirects to dev.va.gov' do
      allow(Settings).to receive(:vsp_environment).and_return('sandbox')
      redirect_url = subject.get_redirect_url({ status: 'status', vendor: vendor })

      expect(redirect_url).to eq 'https://dev.va.gov/health-care/connected-devices/?fitbit=status#_=_'
    end

    it 'production redirects to va.gov' do
      allow(Settings).to receive(:vsp_environment).and_return('production')
      redirect_url = subject.get_redirect_url({ status: 'status', vendor: vendor })

      expect(redirect_url).to eq 'https://www.va.gov/health-care/connected-devices/?fitbit=status#_=_'
    end
  end
end
