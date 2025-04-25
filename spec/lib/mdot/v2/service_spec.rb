# frozen_string_literal: true

require 'rails_helper'
require 'mdot/v2/service'

describe MDOT::V2::Service do
  let(:user_details) do
    {
      first_name: 'patient',
      middle_name: nil,
      last_name: 'test',
      birth_date: '19220222',
      ssn: '000003322',
      icn: '1234123412341234'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }
  let(:cassette_data) { YAML.load_file("spec/support/vcr_cassettes/#{cassette}.yml") }
  let(:token) { cassette_data['http_interactions'].first['request']['headers']['VaApiKey']&.first }

  let(:form_data) { nil }
  let(:service) { MDOT::V2::Service.new(user:, form_data:) }

  around do |ex|
    # Keep request header names SCREAMING_SNAKE_CASE, instead of Kebab-Case. It's an important detail.
    VCR.configure { |c| c.hook_into :faraday }

    options = {
      record: :none,
      record_on_error: false,
      allow_unused_http_interactions: false
    }.merge(VCR::MATCH_EVERYTHING)
    VCR.use_cassette(cassette, options) { ex.run }

    # Switch back to :webmock, as in spec/rails_helper.rb
    VCR.configure { |c| c.hook_into :webmock }
  end

  describe '#authenticate' do
    context 'veteran is authorized' do
      let(:cassette) { 'mdot/v2/20250414203819-get-supplies' }

      it 'returns true' do
        expect(service.authenticate).to be(true)
      end

      it 'creates a redis-backed session' do
        service.authenticate
        expect(service.session).to be_a(Common::RedisStore)
      end

      it 'sets the supplies_resource attribute' do
        expect(service.supplies_resource).to be_nil
        service.authenticate
        expected_keys = %w[permanentAddress temporaryAddress vetEmail supplies]
        expect(service.supplies_resource.keys).to match_array(expected_keys)
      end
    end

    context 'veteran is unauthorized' do
      let(:cassette) { 'mdot/v2/20250416181933-get-supplies' }

      it 'raises MDOT_V2_401' do
        expect { service.authenticate }.to raise_exception(MDOT::V2::ServiceException) do |error|
          expect(error.key).to eq('MDOT_V2_401')
        end
      end
    end

    context 'system-of-record experiences a SQL query error' do
      let(:cassette) { 'mdot/v2/20250415145657-get-supplies' }

      it 'raises MDOT_V2_500' do
        expect { service.authenticate }.to raise_exception(MDOT::V2::ServiceException) do |error|
          expect(error.key).to eq('MDOT_V2_500')
        end
      end
    end

    context 'system-of-record is unavailable' do
      let(:cassette) { 'mdot/v2/20250415143659-get-supplies' }

      it 'raises MDOT_V2_503' do
        expect { service.authenticate }.to raise_exception(MDOT::V2::ServiceException) do |error|
          expect(error.key).to eq('MDOT_V2_503')
        end
      end
    end
  end

  describe '#create_order' do
    let(:permanentAddress) do # rubocop:disable RSpec/VariableName
      {
        street: '123 ASH CIRCLE',
        street2: ', ',
        city: 'ASHVILLE',
        state: 'NC',
        country: 'UNITED STATES',
        postalCode: '77733'
      }
    end

    let(:form_data) do
      {
        useVeteranAddress: true,
        useTemporaryAddress: false,
        vetEmail: 'veteran@va.gov',
        permanentAddress:,
        temporaryAddress: {},
        order: [
          { productId: '5939' }
        ]
      }
    end

    context 'with a valid session' do
      let(:cassette) { 'mdot/v2/20250417162831-post-supplies' }
      let!(:session) { MDOT::V2::Session.create({ uuid: user.uuid, token: }) }

      it 'creates an order with the system of record' do
        service.create_order
        expect(service.orders.first['status']).to eq('Order Processed')
      end
    end

    context 'order was not completed' do
      let(:cassette) { 'mdot/v2/20250417134531-post-supplies' }
      let!(:session) { MDOT::V2::Session.create({ uuid: user.uuid, token: }) }

      it 'raises an error when orderID is zero'
    end
  end
end
