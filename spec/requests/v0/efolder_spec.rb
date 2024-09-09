# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe 'VO::Efolder', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/efolder' do
    stub_efolder_documents(:index)

    it 'shows all documents available to the veteran' do
      get '/v0/efolder'
      expect(JSON.parse(response.body)).to eq(list_documents_res)
    end
  end

  describe 'GET /v0/efolder/{id}' do
    stub_efolder_documents(:show)

    it 'sends the doc pdf' do
      get "/v0/efolder/#{CGI.escape(document_id)}", params: { filename: 'test.pdf' }
      expect(response.body).to eq(content)
    end
  end
end
