# frozen_string_literal: true

require 'rails_helper'
require 'mhv_ac/client'

describe 'mhv account creation' do
  let(:client) { MHVAC::Client.new }
  # If building this for a different user, you will need to fetch an ICN to do so you will need to pass the following:
  # bundle exec rake mvi:find first_name="Hector" middle_name="J" last_name="Allen" _
  #                           birth_date="1932-02-05" gender="M" ssn="796126859"

  let(:upgrade_params) do
    {
      user_id: '14221465',
      form_signed_date_time: time.httpdate,
      terms_version: 'v3.4'
    }
  end
  let(:user_params) do
    {
      icn: '1012667122V019349',
      is_veteran: true,
      is_patient: true,
      first_name: 'Hector',
      last_name: 'Allen',
      ssn: '796126859',
      birth_date: '1932-02-05',
      gender: 'Male',
      address1: '20140624',
      city: 'Houston',
      state: 'Tx',
      country: 'USA',
      zip: '77040',
      sign_in_partners: 'VA.GOV',
      email: 'vets.gov.user+0@gmail.com',
      terms_accepted_date: time,
      terms_version: 'v3.2'
    }
  end
  let(:time) { Time.parse('Tue, 09 May 2017 00:00:00 GMT').utc }

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
    expect(client_response).to be_a(Hash)
  end

  it 'upgrades an account', :vcr do
    client_response = client.post_upgrade(upgrade_params)
    expect(client_response).to be_a(Hash)
  end

  it 'does not create an account if one already exists', :vcr do
    expect { client.post_register(user_params) }
      .to raise_error(Common::Exceptions::BackendServiceException)
  end

  it 'does not upgrade an account if one already exists', :vcr do
    expect { client.post_upgrade(upgrade_params) }
      .to raise_error(Common::Exceptions::BackendServiceException)
  end
end
