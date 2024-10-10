# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe 'Mobile::V0::Efolder', type: :request do
  include JsonSchemaMatchers

  describe 'GET /v0/efolder' do
    let!(:user) { sis_user }

    context 'with an authorized user' do
      stub_efolder_documents(:index)

      let!(:efolder_response) do
        { 'data' => [{ 'id' => '{93631483-E9F9-44AA-BB55-3552376400D8}', 'type' => 'efolder_document',
                       'attributes' => { 'docType' => '1215',
                                         'typeDescription' => 'DMC - Debt Increase Letter',
                                         'receivedAt' => '2020-05-28' } }] }
      end

      it 'and a result that matches our schema is successfully returned with the 200 status' do
        get '/mobile/v0/efolder', headers: sis_headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(efolder_response)
      end
    end
  end
end
