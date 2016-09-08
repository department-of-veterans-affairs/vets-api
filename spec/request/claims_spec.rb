# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Claims management', type: :request do
  it 'lists all Claims' do
    VCR.use_cassette('evss/claims/claims') do
      get '/v0/claims'
      expect(response).to match_response_schema('claims')
    end
  end

  it 'sets 5103 waiver when requesting a decision' do
    VCR.use_cassette('evss/claims/set_5103_waiver') do
      post '/v0/claims/189625/request_decision'
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end

  it 'uploads documents supporting a claim' do
    doctors_note = fixture_file_upload(
      "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
      'application/pdf'
    )
    post '/v0/claims/189625/documents?tracked_item=33', file: doctors_note
    expect(response).to be_success
  end
end
