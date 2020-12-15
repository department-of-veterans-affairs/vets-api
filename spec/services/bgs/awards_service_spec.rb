# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::AwardsService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#get_awards' do
    context 'with a valid participant id' do
      it 'returns the reward amounts' do
        VCR.use_cassette('bgs/awards_service/get_awards') do
          service = BGS::AwardsService.new(user)
          response = service.get_awards
          expect(response[:gross_amt]).to eq('541.83')
        end
      end
    end

    context 'BGS does not return a response' do
      it 'does not return rewards amounts' do
        service = BGS::AwardsService.new(user)
        response = service.get_awards
        expect(response).to eq(false)
      end
    end
  end

  describe '#gross_amount' do
    context 'with a valid participant id' do
      it 'returns the gross amount' do
        VCR.use_cassette('bgs/awards_service/get_awards') do
          service = BGS::AwardsService.new(user)
          gross_amount = service.gross_amount
          expect(gross_amount).to eq('541.83')
        end
      end
    end
  end
end
