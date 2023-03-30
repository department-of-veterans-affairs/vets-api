# frozen_string_literal: true

require 'rails_helper'

class OliveBranchPatchController < ActionController::API
  def respond_with_data
    response = params['data']
    render json: response.to_json.gsub(/"(true|false|\d+)"/) { |quoted_value| quoted_value.gsub('"', '') }
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
      get 'some_json' => 'olive_branch_patch#respond_with_data'
      get 'some_document' => 'olive_branch_patch#document'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  it 'does not change response keys when camel inflection is not used' do
    data = { hello_to_the_va: 'greetingsVA' }
    get '/some_json', params: { data: }, headers: { 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['hello_to_the_va']
    expect(json['hello_to_the_va']).to eq data[:hello_to_the_va]
  end

  # camelCase would keep the leading `va` in lower case
  it 'keeps keys with leading va in lower' do
    data = { va_key: 'valueForVA' }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['vaKey']
  end

  it 'does not change document responses' do
    # this pdf fixture chosen arbitrarily
    params = { path: 'spec/fixtures/pdf_fill/21-0781a/simple.pdf' }
    get '/some_document',
        params:,
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    expect(response).to have_http_status(:ok)
  end

  it 'does not change keys if `VA` is not in the middle of a key' do
    data = { hello_there: 'hello there' }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['helloThere']
    expect(json['helloThere']).to eq data[:hello_there]
  end

  it 'changes `VA` keys containing a colon' do
    data = { 'view:has_va_medical_records' => true }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['view:hasVaMedicalRecords']
    expect(json['view:hasVaMedicalRecords']).to eq data['view:has_va_medical_records']
  end

  it 'changes a key with `VA` to be `Va`' do
    data = { year_va_founded: 1989 }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['yearVaFounded']
    expect(json['yearVaFounded']).to eq data[:year_va_founded]
  end

  it 'changes keys with `VA` to use `Va` for each instance of `VA`' do
    data = { we_love_the_va: true, thumbs_up_for_the_va: 'two' }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq %w[weLoveTheVa thumbsUpForTheVa]
    expect(json['weLoveTheVa']).to eq data[:we_love_the_va]
    expect(json['thumbsUpForTheVa']).to eq data[:thumbs_up_for_the_va]
  end

  it 'changes a `VA` key to `Va` with a nested object in the value' do
    data = { the_va_address: {
      'name' => 'Veteran Affairs Building',
      'street' => '810 Vermont Avenue NW',
      'city' => 'Washington',
      'state' => 'D.C.',
      'country' => 'U.S.',
      'notes' => { 'url' => 'va.gov' }
    } }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['theVaAddress']
    expect(json['theVaAddress']).to eq data[:the_va_address]
  end

  it 'changes a `VA` key to `Va` with an array value' do
    data = { three_va_administrations: ['VHA', 'VBA', 'National Cemetery Administration'] }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['threeVaAdministrations']
    expect(json['threeVaAdministrations']).to eq data[:three_va_administrations]
  end

  it 'changes a `VA` key with a null value' do
    data = { year_va_closes: nil }
    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }
    json = JSON.parse(response.body)
    expect(json.keys).to eq ['yearVaCloses']
    expect(json['yearVaCloses']).to eq data[:year_va_closes]
  end

  it 'changes `VA` keys in complex example' do
    data = {
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

    get '/some_json',
        params: { data: },
        headers: { 'X-Key-Inflection' => 'camel', 'Content-Type' => 'application/json' }

    json = JSON.parse(response.body)
    expect(json.keys).to include('someVaDetails', 'helloThere', 'helloToTheVa')

    expect(json['someVaDetails'].keys).to eq %w[
      yearVaFounded yearVaCloses listsForVa theVaAddress weLoveTheVa thumbsUpForTheVa differentKey
    ]

    url_for_va = data.dig(:some_va_details, 'the_va_address', 'notes', 'url_for_va')
    expect(json.dig('someVaDetails', 'theVaAddress', 'notes', 'urlForVa')).to eq url_for_va
    expect(json['helloThere']).to eq data[:hello_there]
    expect(json['helloToTheVa']).to eq data[:hello_to_the_va]
  end
end
