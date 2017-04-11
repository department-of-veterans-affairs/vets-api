# frozen_string_literal: true
require 'rails_helper'
require 'mhv_ac/client'

describe 'mhv account creation and maintenance client' do
  context 'non session interactions' do
    let(:client) { MHVAC::Client.new(session: nil) }
    let(:user_params) do
      {
        icn: '1008704012V552302',
        first_name: 'Joe',
        last_name: 'Bob',
        ssn: '196-03-0112',
        birth_date: '1984-08-01',
        gender: 'Male',
        address1: '123 Main St',
        city: 'Laurel',
        state: 'MD',
        country: 'USA',
        zip: '12345',
        signInPartners: 'VETS.GOV',
        email: 'test@test.com',
        termsAcceptedDate: 'Mon, 09 Jan 2017 00:00:00 GMT'
      }
    end

    it 'fetches a list of states', :vcr do
      client_response = client.get_states
      expect(client_response).to be_a(Hash)
    end

    it 'fetches a list of countries', :vcr do
      client_response = client.get_countries
      expect(client_response).to be_a(Hash)
    end

    it 'creates an account', :vcr do
      client_response = client.post_register(user_params)
    end
  end

  context 'account upgrading' do
    xit 'upgrades an account', :vcr do
      # client_response = client.upgrade
    end
  end

  context 'account management' do
    before(:all) do
      VCR.use_cassette 'mhv_account_creation_and_maintenance_client/account_management/session', record: :new_episodes do
        @client ||= begin
          client = MHVAC::Client.new(session: { user_id: '12210827' })
          client.authenticate
          client
        end
      end
    end

    let(:client) { @client }

    it 'fetches email settings for notifications', :vcr do
      client_response = client.get_notification_email_address
      expect(client_response).to eq(email_address: 'Praneeth.Gaganapally@va.gov')
    end

    it 'fetches rx preference flag', :vcr do
      client_response = client.get_rx_preference_flag
      expect(client_response).to eq(flag: true)
    end

    it 'fetches appt preference flag', :vcr do
      client_response = client.get_appt_preference_flag
      expect(client_response).to eq(flag: false)
    end

    it 'changes email notification settings back and forth', :vcr do
      client_response = client.post_notification_email_address(email_address: 'kamyar.karshenas@va.gov')
      expect(client_response).to be_success
      client_response = client.get_notification_email_address
      expect(client_response).to eq(email_address: 'kamyar.karshenas@va.gov')
      client_response = client.post_notification_email_address(email_address: 'Praneeth.Gaganapally@va.gov')
      expect(client_response).to be_success
      client_response = client.get_notification_email_address
      expect(client_response).to eq(email_address: 'Praneeth.Gaganapally@va.gov')
    end

    it 'changes rx preference flag back and forth', :vcr do
      client_response = client.post_rx_preference_flag(false)
      expect(client_response).to be_success
      client_response = client.get_rx_preference_flag
      expect(client_response).to eq(flag: false)
      client_response = client.post_rx_preference_flag(true)
      expect(client_response).to be_success
      client_response = client.get_rx_preference_flag
      expect(client_response).to eq(flag: true)
    end

    it 'changes appts preference flag back and forth', :vcr do
      client_response = client.post_appt_preference_flag(true)
      expect(client_response).to be_success
      client_response = client.get_appt_preference_flag
      expect(client_response).to eq(flag: true)
      client_response = client.post_appt_preference_flag(false)
      expect(client_response).to be_success
      client_response = client.get_appt_preference_flag
      expect(client_response).to eq(flag: false)
    end
  end
end
