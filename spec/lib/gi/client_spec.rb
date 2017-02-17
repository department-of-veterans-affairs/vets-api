# frozen_string_literal: true
require 'rails_helper'
require 'gi/client'

describe 'gi client' do
  let(:client) { GI::Client.new }

  it 'gets a list of autocomplete suggestions', :vcr do
    client.get_autocomplete_suggestions('university')
  end

  it 'gets the calculator constants', :vcr do
    client.get_calculator_constants
  end

  it 'gets search results', :vcr do
    client.get_search_results(name: 'illinois')
  end

  it 'gets the institution details', :vcr do
    client.get_institution_details('20603613')
  end
end
