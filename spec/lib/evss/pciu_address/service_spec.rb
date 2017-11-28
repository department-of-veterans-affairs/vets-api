# frozen_string_literal: true
require 'rails_helper'

describe EVSS::PCIUAddress::Service do
  let(:user) { build(:user, :loa3) }
  subject { described_class.new(user) }

  describe '#get_countries' do
    context 'with a 200 response' do
      it 'returns a list of countries' do
        VCR.use_cassette('evss/pciu_address/countries') do
          response = subject.get_countries
          expect(response).to be_ok
          expect(response.countries[0...10]).to eq(
            %w(Afghanistan Albania Algeria Angola Anguilla Antigua Antigua\ and\ Barbuda Argentina Armenia Australia)
          )
        end
      end
    end
  end

  describe '#get_states' do
    context 'with a 200 response' do
      it 'returns a list of states' do
        VCR.use_cassette('evss/pciu_address/states') do
          response = subject.get_states
          expect(response).to be_ok
          expect(response.states[0...10]).to eq(
            %w(AL AK AZ AR CA CO CT DE FL GA)
          )
        end
      end
    end
  end

  describe '#get_address' do
    context 'with a 200 response' do
      it 'returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/address') do
          response = subject.get_address
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#update_address' do
    context 'with a valid address update' do
      let(:update_address) { build(:pciu_domestic_address) }

      it 'updates and returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/address_update') do
          response = subject.update_address(update_address)
          expect(response).to be_ok
        end
      end
    end

    context 'with evss internal server error' do
      let(:update_address) { build(:pciu_domestic_address) }

      it 'returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/update_invalid') do
          expect { subject.update_address(update_address) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
