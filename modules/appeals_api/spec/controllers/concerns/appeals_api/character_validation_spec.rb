# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

class FakeController < ApplicationController
  skip_before_action :authenticate
  include AppealsApi::CharacterValidation
  before_action :validate_characters
end

describe FakeController do
  controller do
    def create
      params.permit!
      # dummy action
    end
  end

  let(:parsed) { JSON.parse(response.body) }

  context 'characters able to be downgraded to Windows-1252' do
    let!(:downgradable_data) { fixture_as_json 'invalid_200996_characters.json', version: 'v2' }

    it 'succeeds' do
      downgradable_data['data']['attributes']['benefitType'] = 'Smartquotes: “”‘’'
      post :create, params: downgradable_data
      expect(response.status).to eq 204
    end
  end

  context 'characters unable to be downgraded to Windows-1252' do
    let(:invalid_data) { fixture_as_json 'invalid_200996_characters.json', version: 'v2' }
    let(:invalid_headers) { fixture_as_json 'invalid_200996_headers_characters.json', version: 'v2' }

    it 'logs & returns an error' do
      expect(Rails.logger).to receive(:error).once

      request.headers.merge!(invalid_headers)
      post :create, params: invalid_data

      expect(response.status).to eq(422)
      expect(parsed['errors'][0]['detail']).to include 'Invalid characters'
      expect(parsed['errors'][0]['meta']).to include 'pattern'
    end
  end
end
