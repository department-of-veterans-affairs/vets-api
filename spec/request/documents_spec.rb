# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  it 'should upload a file' do
    VCR.use_cassette('evss/documents/upload') do
      doctors_note = fixture_file_upload(
        "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
        'application/pdf'
      )
      params = { file: doctors_note, tracked_item: 33 }
      post '/v0/disability_claims/189625/documents', params
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end
end
