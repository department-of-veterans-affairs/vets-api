# frozen_string_literal: true

require 'rails_helper'
require 'gi/client'

describe 'gi client' do
  let(:client) { GI::Client.new }

  it 'gets a list of autocomplete suggestions', :vcr do
    client_response = client.get_autocomplete_suggestions(term: 'university')
    expect(client_response[:data]).to be_an(Array)
    # TODO: This should probably be fixed to conform to JSONAPI
    # expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets the calculator constants', :vcr do
    client_response = client.get_calculator_constants
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets search results', :vcr do
    client_response = client.get_search_results(name: 'illinois')
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes, :links)
  end

  it 'gets the institution details', :vcr do
    client_response = client.get_institution_details(id: '20603613')
    expect(client_response[:data]).to be_a(Hash)
    expect(client_response[:data].keys).to contain_exactly(:id, :type, :attributes, :links)
  end
end
