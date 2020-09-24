# frozen_string_literal: true

require 'rails_helper'
require 'gi/search_client'

describe GI::SearchClient do
  let(:client) { described_class.new }

  it 'gets institution search results', :vcr do
    client_response = client.get_institution_search_results(name: 'illinois').body
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes, :links)
  end

  it 'gets institution program search results', :vcr do
    client_response = client.get_institution_program_search_results(name: 'code').body
    expect(client_response[:data]).to be_an(Array)
    expect(client_response[:data].first.keys).to contain_exactly(:id, :type, :attributes)
  end
end
