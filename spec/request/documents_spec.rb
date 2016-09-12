# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  it 'should fail if no file is provided' do
    post '/v0/claims/1/documents'
    expect(response).to_not be_success
  end

  it 'should upload a file' do
    VCR.use_cassette('evss/documents/create') do
      doctors_note = fixture_file_upload(
        "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
        'application/pdf'
      )
      params = { file: doctors_note, tracked_item: 33 }
      post '/v0/claims/3/documents', params
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end
end
