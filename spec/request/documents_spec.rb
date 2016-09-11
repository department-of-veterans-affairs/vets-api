# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  it 'should fail if no file is provided' do
    post '/v0/claims/1/documents'
    expect(response).to_not be_success
  end
end
