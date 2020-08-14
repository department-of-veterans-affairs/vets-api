# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_efolder_documents'

RSpec.describe V0::EfolderController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    stub_document(:index)

    it 'lists document id and document details for efolder documents' do
      get(:index)
      expect(JSON.parse(response.body)).to eq(list_letters_res)
    end
  end

  describe '#show' do
    stub_document(:show)

    it 'sends the doc pdf' do
      get(:show, params: { id: document_id })
      expect(response.body).to eq(content)
    end
  end
end
