# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/one_debt_letter_service'

RSpec.describe DebtsApi::V0::OneDebtLetterService, type: :service do
  describe '#get_pdf' do
    let(:user) { build(:user, :loa3) }

    context 'combining PDFs' do
      it 'returns a combined pdf when a document is provided' do
        service = DebtsApi::V0::OneDebtLetterService.new(user)
        mock_pdf = StringIO.new('%PDF-1.6 mock pdf content')
        expect(service).to receive(:combine_pdfs).with(mock_pdf)
        service.get_pdf(mock_pdf)
      end

      it 'handles errors during PDF combination' do
        allow(StatsD).to receive(:increment)
        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::OneDebtLetterService::STATS_KEY}.error"
        )

        service = DebtsApi::V0::OneDebtLetterService.new(user)
        mock_pdf = StringIO.new('%PDF-1.6 mock pdf content')
        allow(service).to receive(:load_legalese_pdf).and_raise(StandardError, 'PDF load error')

        expect { service.get_pdf(mock_pdf) }.to raise_error(StandardError, 'PDF load error')
      end
    end
  end
end
