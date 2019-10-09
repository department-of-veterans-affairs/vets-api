# frozen_string_literal: true

require 'rails_helper'
require 'gi/client'

describe 'gi client' do
  let(:client) { GI::Client.new }

  it 'gets a list of institution autocomplete suggestions', :vcr do
    client_response = client.get_institution_autocomplete_suggestions(term: 'university')
    expect(client_response[:data]).to be_an(Array)
    # TODO: This should probably be fixed to conform to JSONAPI
    # expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets the calculator constants', :vcr do
    client_response = client.get_calculator_constants
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets institution search results', :vcr do
    client_response = client.get_institution_search_results(name: 'illinois')
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes, :links)
  end

  it 'gets the institution details', :vcr do
    client_response = client.get_institution_details(id: '11900146')
    expect(client_response[:data]).to be_a(Hash)
    expect(client_response[:data].keys).to contain_exactly(:id, :type, :attributes, :links)
  end

  it 'gets the institution children', :vcr do
    client_response = client.get_institution_children(id: '10086018')
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes, :links)
  end

  it 'gets the zipcode rate', :vcr do
    client_response = client.get_zipcode_rate(id: '20001')
    expect(client_response[:data]).to be_a(Hash)
    expect(client_response[:data].keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets institution program search results', :vcr do
    client_response = client.get_institution_program_search_results(name: 'code')
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end

  it 'gets a list of institution program autocomplete suggestions', :vcr do
    client_response = client.get_institution_program_autocomplete_suggestions(term: 'code')
    expect(client_response[:data]).to be_an(Array)
  end
end
