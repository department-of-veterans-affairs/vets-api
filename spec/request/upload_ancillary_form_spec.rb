# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upload ancillary form', type: :request do
  include SchemaMatchers

  describe 'Post /v0/upload_ancillary_form' do
    context 'with a valid response' do
      it 'should return a 200 and an upload guid' do
        VCR.use_cassette('upload_ancillary_form') do
          post '/v0/upload_ancillary_form', JSON.parse('{"ancillary_form_attachment": {"file_data": "filename"}}')
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('upload_ancillary_form')
        end
      end
    end
  end
end
