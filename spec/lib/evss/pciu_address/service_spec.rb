# frozen_string_literal: true
require 'rails_helper'

describe EVSS::PCIUAddress::Service do
  let(:user) { build(:loa3_user) }

  describe '#get_countries' do
    context 'with a 200 response' do
      it 'returns a list of countries' do
        VCR.use_cassette('evss/pciu_address/countries') do
          response = subject.get_countries(user)
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
          response = subject.get_states(user)
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
          response = subject.get_address(user)
          expect(response).to be_ok
        end
      end
    end
  end

  describe '#update_address' do
    context 'with a valid address update' do
      let(:update_address) {
        {
          'type' => 'DOMESTIC',
          'addressEffectiveDate' => '2017-08-07T19:43:59.383Z',
          'addressOne' => '225 5th St',
          'addressTwo' => '',
          'addressThree' => '',
          'city' => 'Springfield',
          'stateCode' => 'OR',
          'countryName' => 'USA',
          'zipCode' => '97477',
          'zipSuffix' => ''
        }
      }

      it 'updates and returns a users mailing address' do
        VCR.use_cassette('evss/pciu_address/address_update') do
          response = subject.update_address(user, update_address)
          expect(response).to be_ok
        end
      end
    end
  end
end
