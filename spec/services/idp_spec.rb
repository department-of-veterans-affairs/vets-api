# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib', 'idp', 'mock_client')

RSpec.describe Idp do
  describe '.client' do
    context 'in production' do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('IDP_API_BASE_URL', nil).and_return('https://idp.example.com')
      end

      it 'returns the real client' do
        expect(Idp.client).to be_an_instance_of(Idp::Client)
      end
    end

    context 'in development' do
      before { allow(Rails.env).to receive(:production?).and_return(false) }

      it 'returns the mock client' do
        expect(Idp.client).to be_an_instance_of(Idp::MockClient)
      end
    end

    context 'when cave.idp.mock is false outside production' do
      before do
        allow(Rails.env).to receive(:production?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('IDP_USE_LIVE').and_return(nil)
        allow(Settings).to receive(:dig).and_call_original
        allow(Settings).to receive(:dig).with(:cave, :idp, :mock).and_return(false)
        allow(Settings).to receive(:dig).with(:cave, :idp, :base_url).and_return('https://idp.example.com')
        allow(Settings).to receive(:dig).with(:cave, :idp, :timeout).and_return(15)
      end

      it 'returns the real client' do
        expect(Idp.client).to be_an_instance_of(Idp::Client)
      end
    end

    context 'when IDP_USE_LIVE is set' do
      before do
        allow(Rails.env).to receive(:production?).and_return(false)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with('IDP_USE_LIVE').and_return('true')
        allow(ENV).to receive(:fetch).with('IDP_API_BASE_URL', nil).and_return('https://idp.example.com')
      end

      it 'returns the real client even outside production' do
        expect(Idp.client).to be_an_instance_of(Idp::Client)
      end
    end
  end
end
