# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::VeteranReadinessEmploymentClaim do
  let(:claim) { create(:veteran_readiness_employment_claimm_no_vet_information) }
  let(:user_object) { FactoryBot.create(:evss_user, :loa3) }

  describe '#add_claimant_info' do
    it 'adds veteran information' do
      VCR.use_cassette 'veteran_readiness_employment/add_claimant_info' do
        claim.add_claimant_info(user_object)

        expect(claim.parsed_form['veteranInformation']).to include('VAFileNumber' => '796043735')
      end
    end
  end

  describe '#send_to_vre' do
    it 'adds veteran information' do
      VCR.use_cassette 'veteran_readiness_employment/add_claimant_info' do
        claim.add_claimant_info(user_object)
        faraday_response = double('faraday_connection')
        allow(faraday_response).to receive(:status) { 200 }

        allow_any_instance_of(Faraday::Connection).to receive(:post) { faraday_response }

        response = claim.send_to_vre
        expect(response.status).to eq(200)
      end
    end
  end
end
