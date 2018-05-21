# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upload ancillary form', type: :request do
  include SchemaMatchers

  describe 'Post /v0/upload_ancillary_form' do
    context 'with valid parameters' do
      it 'should return a 200 and an upload guid' do
        post '/v0/upload_ancillary_form', JSON.parse('{"ancillary_form_attachment": {"file_data": "filename"}}')
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('upload_ancillary_form')
      end
    end

    context 'with invalid parameters' do
      it 'should return a 500 with no parameters' do
        post '/v0/upload_ancillary_form', nil
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'should return a 500 with no file_data' do
        post '/v0/upload_ancillary_form', JSON.parse('{"ancillary_form_attachment": {}}')
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
