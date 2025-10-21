# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe 'VO::Efolder', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/efolder' do
    stub_efolder_index_documents
    let(:expected_response) do
      [
        { 'document_id' => '{73CD7B28-F695-4337-BBC1-2443A913ACF6}',
          'doc_type' => '702',
          'type_description' => 'Disability Benefits Questionnaire (DBQ) - Veteran Provided',
          'received_at' => '2024-09-13' },
        { 'document_id' => '{EF7BF420-7E49-4FA9-B14C-CE5F6225F615}',
          'doc_type' => '45',
          'type_description' => 'Military Personnel Record',
          'received_at' => '2024-09-13' }
      ]
    end

    it 'shows all documents available to the veteran' do
      get '/v0/efolder'
      expect(JSON.parse(response.body)).to eq(expected_response)
    end
  end

  describe 'GET /v0/efolder/{id}' do
    stub_efolder_show_document

    it 'sends the doc pdf' do
      get "/v0/efolder/#{CGI.escape(document_id)}", params: { filename: 'test.pdf' }
      expect(response.body).to eq(content)
    end
  end
end
