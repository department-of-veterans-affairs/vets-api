# frozen_string_literal: true

require 'rails_helper'
require 'dgi/fry_dea/service'

RSpec.describe MebApi::DGI::FryDea::Service do
  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
    let(:claimant_id) { 600_000_001 }
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:service) { MebApi::DGI::FryDea::Service.new(user) }

    describe '#post_sponsor' do
      let(:faraday_response) { double('faraday_connection') }

      before do
        allow(faraday_response).to receive(:env)
      end

      context 'when successful' do
        it 'returns a status of 200' do
          VCR.use_cassette('dgi/fry_post_sponsor') do
            response = service.post_sponsor

            expect(response.status).to eq(201)
            expect(response.sponsors).to eq(['{"sponsors": [{"firstName": "Wilfred", "lastName": "Brimley", "sponsorRelationship": "Spouse", "dateOfBirth": "09/27/1934"}]}']) # rubocop:disable Layout/LineLength
          end
        end
      end
    end
  end
end
