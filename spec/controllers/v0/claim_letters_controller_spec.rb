# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ClaimLettersController, type: :controller do
  let(:user) { build(:user, :loa3) }
  let(:document_id) { '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA87}' }
  let(:filename) { 'ClaimLetter-2022-9-22.pdf' }
  let(:list_letters_res) { get_fixture('claim_letter/claim_letter_list') }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    it 'lists document id and letter details for claim letters' do
      get(:index)
      letters = JSON.parse(response.body)
      expected_important_keys = %w[document_id doc_type received_at]

      expect(letters.length).to be > 0
      # We can reference the keys of the first letters since
      # they _should_ all have the same keys.
      expect(letters.first.keys).to include(*expected_important_keys)
    end
  end

  describe '#show' do
    it 'responds with a pdf with a dated filename' do
      get(:show, params: { document_id: })

      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.header['Content-Disposition']).to include("filename=\"#{filename}\"")
    end

    it 'returns a 404 with a not found message if document id does not exist' do
      get(:show, params: { document_id: '{0}' })
      err = JSON.parse(response.body)['errors'].first

      expect(err['status']).to eql('404')
      expect(err['title'].downcase).to include('not found')
    end

    it 'has a dated filename' do
      get(:show, params: { document_id: })

      expect(response.header['Content-Disposition']).to include("filename=\"#{filename}\"")
    end
  end
end
