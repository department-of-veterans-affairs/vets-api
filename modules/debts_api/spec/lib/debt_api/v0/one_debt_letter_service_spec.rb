# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/one_debt_letter_service'
RSpec.describe DebtsApi::V0::OneDebtLetterService, type: :service do
  describe '#get_pdf' do
    let(:user) { build(:user, :loa3) }

    it 'returns a pdf' do
      service = DebtsApi::V0::OneDebtLetterService.new(user)
      pdf = service.get_pdf

      expect(pdf).to be_a(String)
      expect(pdf).to include('%PDF-1.4')
    end
  end
end
