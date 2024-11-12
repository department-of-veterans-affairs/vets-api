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

  context 'V1 API Documentation', type: %i[apivore request] do
    subject(:apivore) { Apivore::SwaggerChecker.instance_for('/v1/apidocs.json') }

    it_behaves_like 'V1 Facility Locator'
  end
end
