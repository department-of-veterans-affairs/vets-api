# frozen_string_literal: true

require 'rails_helper'
require 'evss/reference_data/service'

describe EVSS::ReferenceData::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  describe '#get_countries' do
    context 'with a 200 response' do
      it 'returns a list of countries' do
        VCR.use_cassette('evss/reference_data/countries') do
          expect do
            @response = subject.get_countries
          end.to trigger_statsd_increment('api.external_http_request.EVSS/ReferenceData.success', times: 1)
          expect(@response).to be_ok
          expect(@response.countries[0...10]).to eq(
            ['Afghanistan', 'Albania', 'Algeria', 'Angola', 'Anguilla', 'Antigua', 'Antigua and Barbuda', 'Argentina',
             'Armenia', 'Australia']
          )
        end
      end
    end
  end

  describe '#get_states' do
    context 'with a 200 response' do
      it 'returns a list of states' do
        VCR.use_cassette('evss/reference_data/states') do
          response = subject.get_states
          expect(response).to be_ok
          expect(response.states[0...11]).to eq(
            %w[AK AL AR AS AZ CA CO CT DC DE FL]
          )
        end
      end
    end
  end

  describe '#get_separation_locations' do
    context 'with a 200 response' do
      it 'returns a list of separation_locations' do
        VCR.use_cassette('evss/reference_data/get_intake_sites') do
          expect do
            @response = subject.get_separation_locations
          end.to trigger_statsd_increment('api.external_http_request.EVSS/ReferenceData.success', times: 1)
          expect(@response).to be_ok
          expect(@response.separation_locations[0...3]).to eq(
            [{ 'code' => '98283', 'description' => 'AF Academy' },
             { 'code' => '123558', 'description' => 'ANG Hub' },
             { 'code' => '98282', 'description' => 'Aberdeen Proving Ground' }]
          )
        end
      end
    end
  end
end
