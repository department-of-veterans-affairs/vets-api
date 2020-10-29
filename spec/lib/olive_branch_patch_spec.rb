# frozen_string_literal: true

require 'rails_helper'

class OliveBranchPatchController < ActionController::API
  def params_as_json
    params.permit!
    response = params.reject { |k, _| %w[controller action].include?(k) }
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
      get 'some_json' => 'olive_branch_patch#params_as_json'
      get 'some_document' => 'olive_branch_patch#document'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  it 'does not change response keys when camel inflection is not used' do
    hash = { hello_to_the_va: 'greetings' }
    get '/some_json', params: hash
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['hello_to_the_va']
    expect(json['hello_to_the_va']).to eq hash[:hello_to_the_va]
  end

  # camelCase would keep the leading `va` in lower case
  it 'does not duplicate keys with leading va' do
    hash = { va_key: 'VA Value' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['vaKey']
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
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['helloThere']
    expect(json['helloThere']).to eq hash[:hello_there]
  end

  it 'adds a second key to data with `VA` in the key except the key uses `Va`' do
    hash = { year_va_founded: 1989 }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to include('yearVaFounded', 'yearVAFounded')
    expect(json['yearVaFounded']).to eq json['yearVAFounded']
    expect(json['yearVaFounded']).to eq hash[:year_va_founded]
  end

  it 'adds additional keys to data with `VA` in multiple keys except the keys use `Va` for each instance of `VA`' do
    hash = { we_love_the_va: true, thumbs_up_for_the_va: 'two' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to include(
      'weLoveTheVa',
      'weLoveTheVA',
      'thumbsUpForTheVA',
      'thumbsUpForTheVa'
    )
    expect(json['weLoveTheVa']).to eq json['weLoveTheVA']
    expect(json['thumbsUpForTheVA']).to eq json['thumbsUpForTheVa']
  end

  it 'adds a second `VA` key with a nested object in the value' do
    hash = { the_va_address: {
      'name' => 'Veteran Affairs Building',
      'street' => '810 Vermont Avenue NW',
      'city' => 'Washington',
      'state' => 'D.C.',
      'country' => 'U.S.',
      'notes' => { 'url' => 'va.gov' }
    } }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to include('theVAAddress', 'theVaAddress')
    expect(json['theVAAddress']).to eq json['theVaAddress']
    expect(json['theVaAddress']).to eq hash[:the_va_address]
  end

  it 'adds a second `VA` key with an array value' do
    hash = { three_va_administrations: ['VHA', 'VBA', 'National Cemetery Administration'] }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to include('threeVaAdministrations', 'threeVAAdministrations')
    expect(json['threeVaAdministrations']).to eq json['threeVAAdministrations']
    expect(json['threeVaAdministrations']).to eq hash[:three_va_administrations]
  end

  it 'adds a second `VA` key with an null value' do
    hash = { year_va_closes: nil }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    json = JSON.parse(response.body)
    expect(json.keys).to include('yearVaCloses', 'yearVACloses')
    expect(json['yearVaCloses']).to eq json['yearVACloses']
    expect(json['yearVaCloses']).to eq hash[:year_va_closes]
  end

  it 'adds addtional VA keys in complex example' do
    hash = {
      some_va_details: {
        'year_va_founded' => 1989,
        'year_va_closes' => nil,
        'lists_for_va' => [{ 'three_va_administrations' => ['VHA', 'VBA', 'National Cemetery Administration'] }],
        'the_va_address' => {
          'name' => 'Veteran Affairs Building',
          'street' => '810 Vermont Avenue NW',
          'city' => 'Washington',
          'state' => 'D.C.',
          'country' => 'U.S.',
          'notes' => { 'url_for_va' => 'va.gov' }
        },
        'we_love_the_va' => true,
        'thumbs_up_for_the_va' => 'two',
        'different_key' => 'this one does not say VA'
      },
      hello_there: 'hello there',
      hello_to_the_va: 'greetings'
    }

    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }

    json = JSON.parse(response.body)
    expect(json.keys).to include('someVADetails', 'someVaDetails', 'helloThere', 'helloToTheVA', 'helloToTheVa')

    expect(json['someVADetails'].keys).to include(
      'yearVAFounded', 'yearVACloses', 'listsForVA', 'theVAAddress', 'weLoveTheVA', 'thumbsUpForTheVA', 'differentKey'
    )
    expect(json['someVaDetails'].keys).to include(
      'yearVaFounded', 'yearVaCloses', 'listsForVa', 'theVaAddress', 'weLoveTheVa', 'thumbsUpForTheVa', 'differentKey'
    )

    url_for_va = hash.dig(:some_va_details, 'the_va_address', 'notes', 'url_for_va')
    expect(json.dig('someVADetails', 'theVAAddress', 'notes', 'urlForVA')).to eq url_for_va
    expect(json.dig('someVaDetails', 'theVaAddress', 'notes', 'urlForVa')).to eq url_for_va

    expect(json['helloThere']).to eq hash[:hello_there]

    expect(json['helloToTheVA']).to eq json['helloToTheVa']
    expect(json['helloToTheVa']).to eq hash[:hello_to_the_va]
  end
end
