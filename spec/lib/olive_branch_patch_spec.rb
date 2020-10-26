# frozen_string_literal: true

require 'rails_helper'

class ParamsAsJsonController < ActionController::API
  def index
    params.permit!
    response = params.reject { |k, _| %w[controller action].include?(k) }
    # render json: response.to_json.gsub('"true"', 'true').gsub('"false"', 'false')
    render json: response.to_json.gsub(/\"(true|false|\d+)\"/) { |quoted_value| quoted_value.gsub('"', '') }
  end

  def document
    send_data File.read(params[:path]),
              filename: 'json.pdf',
              type: 'application/pdf',
              disposition: 'attachment'
  end
end

describe 'OliveBranchPatch', type: :request do
  before(:all) do
    Rails.application.routes.draw do
      get 'some_json' => 'params_as_json#index'
      get 'some_document' => 'params_as_json#document'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  it 'does not change response keys when camel inflection is not used' do
    hash = { hello_to_the_va: 'greetings' }
    get '/some_json', params: hash
    expect(JSON.parse(response.body).keys).to eq ['hello_to_the_va']
  end

  it 'does not change document responses' do
    # this pdf fixture chosen arbitrarily
    hash = { path: 'spec/fixtures/pdf_fill/21-0781a/simple.pdf' }
    get '/some_document', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(response).to have_http_status(:ok)
  end

  it 'does not add keys if `VA` is not in the middle of a key' do
    hash = { hello_there: 'hello there' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to eq ['helloThere']
  end

  it 'adds a second key to data with `VA` in the key except the key uses `Va`' do
    hash = { year_va_founded: 1989 }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('yearVaFounded', 'yearVAFounded')
  end

  it 'adds additional keys to data with `VA` in multiple keys except the keys use `Va` for each instance of `VA`' do
    hash = { we_love_the_va: true, thumbs_up_for_the_va: 'two' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include(
      'weLoveTheVa',
      'weLoveTheVA',
      'thumbsUpForTheVA',
      'thumbsUpForTheVa'
    )
  end

  it 'adds a second `VA` key with a nested object in the value' do
    hash = { the_va_address: {
      name: 'Veteran Affairs Building',
      street: '810 Vermont Avenue NW',
      city: 'Washington',
      state: 'D.C.',
      country: 'U.S.'
    } }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('theVAAddress', 'theVaAddress')
  end

  it 'adds a second `VA` key with an array value' do
    hash = { three_va_administrations: ['VHA', 'VBA', 'National Cemetery Administration'] }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('threeVaAdministrations', 'threeVAAdministrations')
  end

  it 'adds a second `VA` key with an null value' do
    hash = { year_va_closes: nil }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('yearVaCloses', 'yearVACloses')
  end
end
