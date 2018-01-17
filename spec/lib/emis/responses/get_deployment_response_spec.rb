# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/get_deployment_response'

describe EMIS::Responses::GetDeploymentResponse do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { Ox.parse(File.read('spec/support/emis/getDeploymentResponse.xml')) }
  let(:response) { EMIS::Responses::GetDeploymentResponse.new(faraday_response) }

  before(:each) do
    allow(faraday_response).to receive(:body) { body }
  end

  describe 'checking status' do
    it 'returns true for ok?' do
      expect(response).to be_ok
    end
  end

  describe 'getting data' do
    context 'with a successful response' do
      it 'gives me an item' do
        expect(response.items.count).to eq(1)
      end

      it 'has the proper segment identifier' do
        expect(response.items.first.segment_identifier).to eq('1')
      end

      it 'has the proper begin date' do
        expect(response.items.first.begin_date).to eq(Date.parse('2008-09-08'))
      end

      it 'has the proper end date' do
        expect(response.items.first.end_date).to eq(Date.parse('2009-04-18'))
      end

      it 'has the proper project code' do
        expect(response.items.first.project_code).to eq('9GF')
      end

      it 'has the proper termination reason' do
        expect(response.items.first.termination_reason).to eq('C')
      end

      it 'has the proper transaction date' do
        expect(response.items.first.transaction_date).to eq(Date.parse('2016-05-18'))
      end

      context 'with a location' do
        let(:location) { response.items.first.locations.first }

        it 'has a location' do
          expect(response.items.first.locations.count).to eq(1)
        end

        it 'has the right segment identifier' do
          expect(location.segment_identifier).to eq('1')
        end

        it 'has the right country' do
          expect(location.country).to eq('AE')
        end

        it 'has the right ISO Alpha3 country' do
          expect(location.iso_alpha3_country).to eq('ARE')
        end

        it 'has the right begin date' do
          expect(location.begin_date).to eq(Date.parse('2008-09-08'))
        end

        it 'has the right end date' do
          expect(location.end_date).to eq(Date.parse('2009-04-18'))
        end

        it 'has the right termination reason code' do
          expect(location.termination_reason_code).to eq('C')
        end

        it 'has the right transaction date' do
          expect(location.transaction_date).to eq(Date.parse('2016-05-14'))
        end
      end
    end
  end
end
