require 'rails_helper'
require 'mdot/v2/service'

describe MDOT::V2::Service, :focus do
  subject { MDOT::V2::Service.new(user) }

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

  around do |ex|
    VCR.configure do |c|
      c.hook_into :faraday
      # c.debug_logger = $stderr # or File.open('vcr.log', 'w')
    end

    options = {
      record: :none,
      record_on_error: false,
      allow_unused_http_interactions: false
    }.merge(VCR::MATCH_EVERYTHING)
    VCR.use_cassette(cassette, options) { ex.run }

    VCR.configure do |c|
      c.hook_into :webmock
      # c.debug_logger = nil
    end
  end

  describe '#authenticate' do
    context 'veteran is authorized' do
      let!(:cassette) { 'mdot/v2/20250414203819-get-supplies' }

      it 'creates a redis-backed session' do
        subject.authenticate
        expect(subject.send(:session)).to be_a(Common::RedisStore)
      end

      it 'sets the supplies_resource attribute' do
        expect(subject.supplies_resource).to be_nil
        subject.authenticate
        expected_keys = %w[permanentAddress temporaryAddress vetEmail supplies]
        expect(subject.supplies_resource.keys).to match_array(expected_keys)
      end
    end

    context 'veteran is unauthorized' do
      let(:cassette) { '/mdot/v2/20250415145657-get-supplies' }

      it 'blows up' do
        subject.authenticate
      end
    end

    # context ''
  end

  describe '#create_order' do
    let(:permanentAddress) do
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

    let(:cassette) { 'mdot/v2/20250417162831-post-supplies' }
    let(:session) { MDOT::V2::Session.create({ uuid: user.uuid, token: 'abcd1234abcd1234abcd1234abcd1234abcd1234' }) }

    it 'creates an order with the system of record' do
      allow_any_instance_of(MDOT::V2::Service).to receive(:session).and_return(session)
      subject.create_order(form_data)
      expect(subject.orders.first['status']).to eq('Order Processed')
    end
  end
end
