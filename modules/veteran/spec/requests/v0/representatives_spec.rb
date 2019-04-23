# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VSO representative spec', type: :request do
  let(:representative) { FactoryBot.create(:representative, first_name: 'Bob', last_name: 'Smith', poa: '1BQ') }

  before do
    representative
  end

  it 'should find a VSO rep' do
    get '/services/veteran/v0/representatives/search', params: { first_name: 'Bob', last_name: 'Smith' }
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['data']['first_name']).to eq('Bob')
    expect(parsed_response['data']['last_name']).to eq('Smith')
    expect(parsed_response['data']['power_of_attorney_code']).to eq('1BQ')
  end

  it 'should find return a proper error' do
    get '/services/veteran/v0/representatives/search', params: { first_name: 'Bob', last_name: 'Jones' }
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['errors'].first['detail']).to eq('Representative not found')
  end
end
