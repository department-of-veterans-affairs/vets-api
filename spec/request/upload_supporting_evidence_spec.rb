# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upload supporting evidence', type: :request do
  include SchemaMatchers

  describe 'Post /v0/upload_supporting_evidence' do
    context 'with valid parameters' do
      it 'should return a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             JSON.parse('{"supporting_evidence_attachment": {"file_data": "filename"}}')
        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('upload_supporting_evidence')
      end
    end

    context 'with invalid parameters' do
      it 'should return a 500 with no parameters' do
        post '/v0/upload_supporting_evidence', nil
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'should return a 500 with no file_data' do
        post '/v0/upload_supporting_evidence', JSON.parse('{"supporting_evidence_attachment": {}}')
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
