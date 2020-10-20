# frozen_string_literal: true

require 'rails_helper'

class ParamsAsJsonController < ActionController::API
  def index
    params.permit!
    render json: params.reject { |k, _| %w[controller action].include?(k) }.to_json
  end
end

describe 'OliveBranchPatch', type: :request do
  before(:all) do
    Rails.application.routes.draw do
      get 'some_json' => 'params_as_json#index'
    end
  end

  after(:all) do
    Rails.application.reload_routes!
  end

  it 'does not change response keys when camel inflection is not used' do
    hash = { hello_there: 'hello there' }
    get '/some_json', params: hash
    expect(JSON.parse(response.body).keys).to eq ['hello_there']
  end
  it 'does not change a Rack::Response response object'
  it 'does not add keys if `VA` is not in the middle of a key' do
    hash = { hello_there: 'hello there' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to eq ['helloThere']
  end
  it 'adds a second key to data with `VA` in the key except the key uses `Va`' do
    hash = { we_love_the_va: true }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('weLoveTheVa', 'weLoveTheVA')
  end
  it 'adds additional keys to data with `VA` in multiple keys except the keys use `Va` for each instance of `VA`'  do
    hash = { we_love_the_va: true, the_va_loves_our_troops: true }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to include('weLoveTheVa', 'weLoveTheVA', 'theVALovesOurTroops', 'theVaLovesOurTroops')
  end
end
