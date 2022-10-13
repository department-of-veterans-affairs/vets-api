# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ClaimLettersController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:document_id) { '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA87}' }
  let(:list_letters_res) { get_fixture('claim_letter/claim_letter_list') }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    it 'lists document id and letter details for claim letters' do
      get(:index)
      expect(JSON.parse(response.body)).to eq(list_letters_res)
    end
  end

  describe '#show' do
    it 'sends the letter pdf' do
      get(:show, params: { document_id: document_id })

      expect(response.header['Content-Type']).to eq('application/pdf')
    end
  end
end
