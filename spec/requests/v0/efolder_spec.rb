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

  describe 'GET /v0/efolder/tsa_letter' do
    let(:tsa_letter) do
      {
        document_id: '{73CD7B28-F695-4337-BBC1-2443A913ACF6}',
        doc_type: '34',
        type_description: 'Correspondence',
        received_at: Date.new(2024, 9, 13)
      }
    end

    before do
      expect(efolder_service).to receive(:get_tsa_letter).and_return(
        tsa_letter
      )
    end

    it 'returns the tsa letter metadata' do
      get '/v0/efolder/tsa_letter'
      expect(response.body).to eq(tsa_letter.to_json)
    end
  end

  describe 'GET /v0/efolder/download_tsa_letter' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(efolder_service).to receive(:download_tsa_letter).with(document_id).and_return(content)
    end

    it 'sends the doc pdf' do
      get "/v0/efolder/download_tsa_letter/#{CGI.escape(document_id)}", params: { filename: 'test.pdf' }
      expect(response.body).to eq(content)
    end
  end
end
