# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::Ch33BankAccountsController, type: :controller do
  let(:user) { FactoryBot.build(:ch33_dd_user) }

  before do
    sign_in_as(user)
  end

  context 'unauthorized user' do
    def self.expect_unauthorized
      it 'returns unauthorized' do
        get(:index)
        expect(response.status).to eq(403)
        put(:update)
        expect(response.status).to eq(403)
      end
    end

    context 'with a loa1 user' do
      let(:user) { build(:user, :loa1) }

      expect_unauthorized
    end

    context 'with a flipper disabled user' do
      before do
        allow(User).to receive(:find).with(user.uuid).and_return(user)
        expect(Flipper).to receive(:enabled?).with(:ch33_dd, user).and_return(false).twice
      end

      expect_unauthorized
    end
  end

  describe '#index' do
    it 'returns the right data' do
      VCR.use_cassette('bgs/service/find_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        get(:index)
      end

      expect(JSON.parse(response.body)).to eq(
        {
          'data' => {
            'id' => '', 'type' => 'savon_responses',
            'attributes' => {
              'account_type' => 'Checking', 'account_number' => '123',
              'financial_institution_routing_number' => '*****9982'
            }
          }
        }
      )
    end
  end

  describe '#update' do
    it 'sends the update req' do
      VCR.use_cassette('bgs/service/update_ch33_dd_eft', VCR::MATCH_EVERYTHING) do
        put(
          :update,
          params: {
            account_type: 'Checking',
            account_number: '444',
            financial_institution_routing_number: '122239982'
          }
        )

        expect(
          JSON.parse(response.body)['update_ch33_dd_eft_response']['return']['return_message']
        ).to eq(
          'SUCCESS'
        )
      end
    end
  end
end
