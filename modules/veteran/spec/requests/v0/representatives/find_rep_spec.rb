# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran::V0::Representatives::FindRep', type: :request do
  let!(:representative) { create(:representative, first_name: 'Bob', last_name: 'Smith', poa_codes: ['1B']) }

  it 'finds a VSO rep' do
    get '/services/veteran/v0/representatives/find_rep', params: { first_name: 'Bob', last_name: 'Smith' }
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['data']['attributes']['first_name']).to eq('Bob')
    expect(parsed_response['data']['attributes']['last_name']).to eq('Smith')
    expect(parsed_response['data']['attributes']['poa_codes']).to eq(['1B'])
  end

  it 'finds return a proper error' do
    get '/services/veteran/v0/representatives/find_rep', params: { first_name: 'Bob', last_name: 'Jones' }
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['errors'].first['detail']).to eq('Representative not found')
  end
end
