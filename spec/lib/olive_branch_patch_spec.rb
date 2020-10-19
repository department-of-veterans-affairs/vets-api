# frozen_string_literal: true

require 'rails_helper'

class ParamsAsJsonController < ActionController::API
  def index
    params.permit!
    render json: params.reject { |k,_| %w(controller action).include?(k) } .to_json
  end
end

Rails.application.routes.draw do
  get 'some_json' => 'params_as_json#index'
end

describe 'OliveBranchPatch', type: :request do
  it 'does not change response keys when camel inflection is not used'
  it 'does not add keys if `VA` is not in the middle of a key' do
    hash = { hello_there: 'hello there' }
    get '/some_json', params: hash, headers: { 'X-Key-Inflection' => 'camel' }
    expect(JSON.parse(response.body).keys).to eq ['helloThere']
  end
  it 'adds a second key to data with `VA` in the key except the key uses `Va`'
end
