# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::PreCheckInsController', type: :request do
  let(:id) { Faker::Internet.uuid }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_pre_check_in_enabled').and_return(true)
    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when JWT token and Redis entries are absent' do
      let(:resp) do
        {
          'permissions' => 'read.none',
          'status' => 'success',
          'uuid' => id
        }
      end

      it 'returns unauthorized status' do
        get "/check_in/v2/pre_check_ins/#{id}"

        expect(response.status).to eq(401)
      end

      it 'returns read.none permissions' do
        get "/check_in/v2/pre_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when JWT token and Redis entries are present' do
      let(:next_of_kin1) do
        {
          'name' => 'Joe',
          'relationship' => 'Brother',
          'phone' => '738-573-2849',
          'workPhone' => '564-438-5739',
          'street1' => '432 Horner Street',
          'street2' => 'Apt 53',
          'street3' => '',
          'city' => 'Akron',
          'county' => 'OH',
          'state' => 'OH',
          'zip' => '44308',
          'zip4' => '4252',
          'country' => 'USA'
        }
      end
      let(:emergency_contact) do
        {
          'name' => 'Michael',
          'relationship' => 'Spouse',
          'phone' => '415-322-9968',
          'workPhone' => '630-835-1623',
          'street1' => '3008 Millbrook Road',
          'street2' => '',
          'street3' => '',
          'city' => 'Wheeling',
          'county' => 'IL',
          'state' => 'IL',
          'zip' => '60090',
          'zip4' => '7241',
          'country' => 'USA'
        }
      end
      let(:mailing_address) do
        {
          'street1' => '1025 Meadowbrook Mall Road',
          'street2' => '',
          'street3' => '',
          'city' => 'Beverly Hills',
          'county' => 'Los Angeles',
          'state' => 'CA',
          'zip' => '60090',
          'country' => 'USA'
        }
      end
      let(:home_address) do
        {
          'street1' => '3899 Southside Lane',
          'street2' => '',
          'street3' => '',
          'city' => 'Los Angeles',
          'county' => 'Los Angeles',
          'state' => 'CA',
          'zip' => '90017',
          'country' => 'USA'
        }
      end
      let(:home_phone) { '323-743-2569' }
      let(:mobile_phone) { '323-896-8512' }
      let(:work_phone) { '909-992-3911' }
      let(:email_address) { 'utilside@goggleappsmail.com' }
      let(:demographics) do
        {
          'nextOfKin1' => next_of_kin1,
          'emergencyContact' => emergency_contact,
          'mailingAddress' => mailing_address,
          'homeAddress' => home_address,
          'homePhone' => home_phone,
          'mobilePhone' => mobile_phone,
          'workPhone' => work_phone,
          'emailAddress' => email_address
        }
      end
      let(:appointment1) do
        {
          'appointmentIEN' => '460',
          'zipCode' => '96748',
          'clinicName' => 'Family Wellness',
          'startTime' => '2021-08-19T10:00:00',
          'clinicPhoneNumber' => '555-555-5555',
          'clinicFriendlyName' => 'Health Wellness',
          'facility' => 'VEHU DIVISION',
          'appointmentCheckInStart' => '2021-08-19T09:030:00',
          'appointmentCheckInEnds' => '2021-08-19T10:050:00',
          'eligibility' => 'ELIGIBLE',
          'status' => ''
        }
      end
      let(:resp) do
        {
          'id' => id,
          'payload' => {
            'demographics' => demographics,
            'appointments' => [appointment1]
          }
        }
      end

      before do
        allow_any_instance_of(CheckIn::V2::Session).to receive(:authorized?).and_return(true)
        allow_any_instance_of(::V2::Lorota::Service).to receive(:check_in_data).and_return(resp)
      end

      it 'returns success status' do
        get "/check_in/v2/pre_check_ins/#{id}"

        expect(response.status).to eq(200)
      end

      it 'returns payload in response body' do
        get "/check_in/v2/pre_check_ins/#{id}"

        expect(JSON.parse(response.body)).to eq(resp)
      end
    end
  end

  describe 'POST `create`' do
    let(:post_params) do
      {
        pre_check_in: {
          uuid: id,
          demographics_up_to_date: true,
          next_of_kin_up_to_date: true,
          check_in_type: :preCheckIn
        }
      }
    end

    context 'when session is authorized' do
      let(:success_resp) { Faraday::Response.new(body: 'Pre-checkin successful', status: 200) }

      before do
        allow_any_instance_of(CheckIn::V2::Session).to receive(:authorized?).and_return(true)
        allow_any_instance_of(::V2::Chip::Service).to receive(:pre_check_in).and_return(success_resp)
      end

      it 'returns successful response' do
        post '/check_in/v2/pre_check_ins', params: post_params

        expect(response.body).to eq(success_resp.to_json)
      end
    end

    context 'when session is not authorized' do
      let(:body) { { 'permissions' => 'read.none', 'status' => 'success', 'uuid' => id } }
      let(:unauth_response) { Faraday::Response.new(body: body, status: 401) }

      before do
        allow_any_instance_of(::V2::Chip::Service).to receive(:pre_check_in).and_return(unauth_response)
      end

      it 'returns unauthorized response' do
        post '/check_in/v2/pre_check_ins', params: post_params

        expect(response.body).to eq(unauth_response.body.to_json)
        expect(response.status).to eq(unauth_response.status)
      end
    end
  end
end
