# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds States Integration', type: :request do
  include SchemaMatchers

  before(:each) { allow_any_instance_of(Preneeds::Service).to receive(:expired?).and_return(true) }

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/states/gets_a_list_of_states') do
      get '/v0/preneeds/states/'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('preneeds/states')
  end
end
