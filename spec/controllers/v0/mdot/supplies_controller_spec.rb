# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::MDOT::SuppliesController, type: :controller do
  context 'successful request' do
    before do
      sign_in_as(user)
    end

    describe '#create' do
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

  context 'unsuccessful request' do
    around do |ex|
      # Keep request header names SCREAMING_SNAKE_CASE, instead of Kebab-Case. It's an important detail.
      VCR.configure { |c| c.hook_into :faraday }

      options = {
        record: :none,
        record_on_error: false,
        allow_unused_http_interactions: false,
        match_requests_on: %i[method uri headers body]
      }
      VCR.use_cassette(cassette, options) { ex.run }

      # Switch back to :webmock, as in spec/rails_helper.rb
      VCR.configure { |c| c.hook_into :webmock }
    end

    describe '#create -- 200 status, orderID: 0' do
      let(:user) { build(:user, :loa3) }
      let(:cassette_data) { YAML.load_file("spec/support/vcr_cassettes/#{cassette}.yml") }
      let(:token) { cassette_data['http_interactions'].first['request']['headers']['VaApiKey'].first }
      let(:create_mdot_session) { MDOT::Token.new({ uuid: user.uuid, token: }) }

      let(:cassette) { 'mdot/20250502194520-post-supplies' }

      let(:permanent_address) do
        {
          street: '1000 NOWHERE PL',
          street2: ',',
          city: 'OKAY',
          state: 'OK',
          country: 'UNITED STATES',
          postal_code: '80004'
        }
      end

      let(:params) do
        {
          use_veteran_address: true,
          use_temporary_address: false,
          vetEmail: 'veteran@example.com',
          permanent_address:,
          temporary_address: {},
          order: [
            { product_id: 8271 }
          ]
        }
      end

      it 'does the thing' do
        sign_in_as(user)
        create_mdot_session
        post(:create, params:)
      end
    end
  end
end
