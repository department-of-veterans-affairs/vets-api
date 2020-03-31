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
        'permanent_address' => {
          'street' => '101 Example Street',
          'street2' => 'Apt 2',
          'city' => 'Kansas City',
          'state' => 'MO',
          'country' => 'USA',
          'postal_code' => '64117'
        },
        'use_permanent_address' => true,
        'use_temporary_address' => false,
        'order' => [{ 'product_id' => '1' }, { 'product_id' => '4' }],
        'additional_requests' => ''
      }
    end

    it 'submits the req to the mdot client' do
      VCR.use_cassette('mdot/submit_order', VCR::MATCH_EVERYTHING) do
        post(:create, body: body.to_json, as: :json)

        res = JSON.parse(response.body)
        expect(res['status']).to eq('success')
        expect(res['order_id']).to match(/[a-z0-9-]+/)
      end
    end
  end
end
