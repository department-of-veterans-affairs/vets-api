# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::MDOT::SuppliesController, type: :controller do
  let(:user_details) do
    {
      first_name: 'Greg',
      last_name: 'Anderson',
      middle_name: 'A',
      birth_date: '1991-04-05',
      ssn: '000550237'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }

  before do
    sign_in_as(user)
  end

  describe '#create' do
    let(:body) do
      {
        'use_veteran_address' => true,
        'use_temporary_address' => false,
        'order' => [{ 'product_id' => 2499 }],
        'permanent_address' => {
          'street' => '125 SOME RD',
          'street2' => 'APT 101',
          'city' => 'DENVER',
          'state' => 'CO',
          'country' => 'United States',
          'postal_code' => '111119999'
        },
        'temporary_address' => {
          'street' => '17250 w colfax ave',
          'street2' => 'a-204',
          'city' => 'Golden',
          'state' => 'CO',
          'country' => 'United States',
          'postal_code' => '80401'
        },
        'vet_email' => 'vet1@va.gov'
      }
    end

    it 'submits the req to the mdot client' do
      VCR.use_cassette('mdot/submit_order', VCR::MATCH_EVERYTHING) do
        set_mdot_token_for(user)
        post(:create, body: body.to_json, as: :json)
        res = JSON.parse(response.body)
        expect(res[0]['status']).to eq('Order Processed')
        expect(res[0]['order_id']).to be_an(Integer)
      end
    end
  end
end
