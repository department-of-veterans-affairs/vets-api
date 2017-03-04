# frozen_string_literal: true
require 'rails_helper'
require 'mhv_account/client'

describe 'mhv account client' do
  let(:client) { MHVAC::Client.new }

  # Need to pull the last updated to determine the staleness / freshness of the data
  # will revisit this later.
  xit 'creates an account', :vcr do
    # client_response = client.register
  end

  # These are the list of eligible data classes that can be used to generate a report
  xit 'upgrades an account', :vcr do
    # client_response = client.upgrade
  end
end
