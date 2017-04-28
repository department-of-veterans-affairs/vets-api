# frozen_string_literal: true
require 'rails_helper'
require 'mhv_ac/client'

describe 'mhv account creation and maintenance client' do
  context 'creation and registration' do
    let(:client) { MHVAC::Client.new(session: nil) }
    # If building this for a different user, you will need to fetch an ICN to do so you will need to pass the following:
    # bundle exec rake mvi:find first_name="Hector" middle_name="J" last_name="Allen" _
    #                           birth_date="1932-02-05" gender="M" ssn="796126859"

    it 'fetches a list of states', :vcr do
      client_response = client.get_states
      expect(client_response).to be_a(Hash)
    end

    it 'fetches a list of countries', :vcr do
      client_response = client.get_countries
      expect(client_response).to be_a(Hash)
    end

    let(:user_params) do
      {
        icn: '1008704012V552302',
        first_name: 'Hector',
        last_name: 'Allen',
        ssn: '796126859',
        birth_date: '1932-02-05',
        gender: 'Male',
        address1: '123 Main St',
        city: 'Laurel',
        state: 'MD',
        country: 'USA',
        zip: '12345',
        signInPartners: 'VETS.GOV',
        email: 'test@test.com',
        termsAcceptedDate: 'Fri, 28 Apr 2017 00:00:00 GMT'
      }
    end

    # These methods are temporarily disabled because they are very difficult to test since MHV verifies MVI.
    # Need to coordinate them with MHV.

    # Currently getting MHV error:
    # "MVI Unknown Issue Occurred", "Error:MVI Response has error : Error Code: AE;"
    # Perhaps the ICN above is not valid.
    xit 'creates an account', :vcr do
      client.post_register(user_params)
    end

    xit 'upgrades an account', :vcr do
      client.upgrade
    end
  end

  context 'preferences' do
    before(:all) do
      VCR.use_cassette 'mhv_account_creation_and_maintenance_client/preferences/session', record: :new_episodes do
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
