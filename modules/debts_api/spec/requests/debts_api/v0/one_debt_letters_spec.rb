# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/one_debt_letter_service'

RSpec.describe 'DebtsApi::V0::OneDebtLetters', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#combine_pdf' do
    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('modules', 'debts_api', 'spec', 'fixtures', '5655.pdf'),
        'application/pdf'
      )
    end

    it 'increments StatsD' do
      allow(StatsD).to receive(:increment)

      expect(StatsD).to receive(:increment).with(
        "#{DebtsApi::V0::OneDebtLetterService::STATS_KEY}.initiated"
      )

      expect(StatsD).to receive(:increment).with(
        "#{DebtsApi::V0::OneDebtLetterService::STATS_KEY}.success"
      )

      post '/debts_api/v0/combine_one_debt_letter_pdf', params: { document: file }
    end
  end
end
