# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MDOT Medical Devices & Supplies', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }

  context 'with an authenticated user' do
    before { sign_in_as(user) }

    it 'lists medical devices and supplies for the veteran' do
      VCR.use_cassette('mdot/get_supplies_200') do
        get '/v0/mdot/supplies'
        expect(response).to match_response_schema('mdot_supplies')
      end
    end
  end
end