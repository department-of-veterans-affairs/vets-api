# frozen_string_literal: true

require 'rails_helper'

Dir.glob(File.expand_path('shared_examples/*.rb', __dir__)).each(&method(:require))

RSpec.describe 'API V1 doc validations', type: :request do
  context 'json validation' do
    it 'has valid json' do
      get '/v1/apidocs.json'
      json = response.body
      JSON.parse(json).to_yaml
    end
  end
end
