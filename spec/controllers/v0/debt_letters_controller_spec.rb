# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_debt_letters'

RSpec.describe V0::DebtLettersController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#index' do
    stub_debt_letters(:index)

    it 'lists document id and letter details for debt letters' do
      get(:index)
      expect(JSON.parse(response.body)).to eq(list_letters_res)
    end
  end

  describe '#show' do
    stub_debt_letters(:show)

    it 'sends the letter pdf' do
      get(:show, params: { id: document_id })

      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(content)
    end
  end
end
