# frozen_string_literal: true

require 'rails_helper'
module Facilities
  RSpec.describe PPMSClient do
    it 'should be an PPMSClient object' do
      expect(described_class.new).to be_an(PPMSClient)
    end

    blank_matcher = lambda { |r1, r2|
      r1.uri.match(r2.uri)
    }

    # WIP just a smoke test
    describe 'route_fuctions' do
      it 'should not be null' do
        VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
          r = PPMSClient.new.test_routes('Providers', 'Identifier': '12345')
          expect(r).not_to be(nil)
        end
      end

      it 'should also not be null' do
        VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
          r = PPMSClient.new.provider_locator('bbox': [73, -60, 74, -61])
          expect(r).not_to be(nil)
        end
      end

      it 'should return a Provider shape' do
        VCR.use_cassette('facilities/va/ppms', match_requests_on: [blank_matcher]) do
          r = PPMSClient.new.provider_info(1_427_435_759)
          expect(r['ProviderIdentifier']).not_to be(nil)
          expect(r['Name']).not_to be(nil)
          expect(r['ProviderSpecialties'].class.name).to eq('Array')
        end
      end

      it 'should edit the parameters' do
        params = PPMSClient.new.build_params('bbox': [73, -60, 74, -61])
        Rails.logger.info(params)
        expect(params[:radius]).to be > 35
      end
    end
  end
end
