# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds Application Integration', type: :request do
  include SchemaMatchers

  context 'with valid input' do
    it 'responds to POST #create' do
      VCR.use_cassette('preneeds/pre_need_applications/creates_a_pre_need_application') do
        post '/v0/preneeds/pre_need_applications'
      end
    end
  end
end
