# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe 'VO::TsaLetter', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/tsa_letter' do
    let(:tsa_letters) do
      [
        OpenStruct.new(
          document_id: '{73CD7B28-F695-4337-BBC1-2443A913ACF6}',
          doc_type: '34',
          type_description: 'Correspondence',
          received_at: Date.new(2024, 9, 13)
        )
      ]
    end

    before do
      expect(efolder_service).to receive(:list_tsa_letters).and_return(tsa_letters)
    end

    it 'returns the tsa letter metadata' do
      expected_response = { 'data' =>
        [{ 'id' => '',
           'type' => 'tsa_letter',
           'attributes' => { 'document_id' => '{73CD7B28-F695-4337-BBC1-2443A913ACF6}', 'doc_type' => '34',
                             'type_description' => 'Correspondence', 'received_at' => '2024-09-13' } }] }
      get '/v0/tsa_letter'
      expect(response.body).to eq(expected_response.to_json)
    end
  end

  describe 'GET /v0/tsa_letter/:id' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(efolder_service).to receive(:get_tsa_letter).with(document_id).and_return(content)
    end

    it 'sends the doc pdf' do
      get "/v0/tsa_letter/#{CGI.escape(document_id)}"
      expect(response.body).to eq(content)
    end
  end
end
