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
end
