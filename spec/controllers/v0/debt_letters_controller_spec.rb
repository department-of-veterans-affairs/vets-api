# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DebtLettersController, type: :controller do
  let(:user) { build(:user, :loa3) }

  let!(:letter_downloader) do
    letter_downloader = double
    expect(Debts::LetterDownloader).to receive(:new).with(user.ssn).and_return(letter_downloader)
    letter_downloader
  end

  before do
    sign_in_as(user)
  end

  describe '#index' do
    let(:list_letters_res) { get_fixture('vbms/list_letters') }

    before do
      expect(letter_downloader).to receive(:list_letters).and_return(
        list_letters_res
      )
    end

    it 'lists document id and letter details for debt letters' do
      get(:index)
      expect(JSON.parse(response.body)).to eq(list_letters_res)
    end
  end

  describe '#show' do
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/pdf_fill/extras.pdf') }

    before do
      expect(letter_downloader).to receive(:get_letter).with(document_id).and_return(content)
    end

    it 'sends the letter pdf' do
      get(:show, params: { id: document_id })

      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(content)
    end
  end
end
