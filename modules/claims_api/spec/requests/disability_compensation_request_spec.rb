# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims ', type: :request do

  before do
    @headers = {'X-VA-SSN': '796043735',
               'X-VA-First-Name': 'WESLEY',
               'X-VA-Last-Name': 'FORD',
               'X-VA-EDIPI': '1007697216',
               'X-Consumer-Username': 'TestConsumer',
               'X-VA-User': 'adhoc.test.user',
               'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
               'X-VA-Gender': 'M'}
    @data = File.read(Rails.root.to_s + "/modules/claims_api/spec/fixtures/form_526.json")
  end

  it 'should return a successful response with all the data' do
    post '/services/claims/v0/forms/526', JSON.parse(@data), @headers
    parsed = JSON.parse(response.body)
    expect(parsed['data']['type']).to eq('claims_api_auto_established_claims')
    expect(parsed['data']['attributes']['status']).to eq('pending')
  end
end
