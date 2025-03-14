# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/one_debt_letter_service'

RSpec.describe DebtsApi::V0::OneDebtLetterService, type: :service do
  describe '#get_pdf' do
    let(:user) { build(:user, :loa3) }
    let(:copay_response) do
      raw_data = JSON.parse(Rails.root.join('modules', 'debts_api', 'spec', 'fixtures', 'copay_response.json').read)
      { data: raw_data['data'] }
    end

    before do
      vbs_service_double = instance_double(MedicalCopays::VBS::Service)
      allow(vbs_service_double).to receive(:get_copays).and_return(copay_response)
      allow(MedicalCopays::VBS::Service).to receive(:build).and_return(vbs_service_double)
    end

    it 'returns a pdf' do
      service = DebtsApi::V0::OneDebtLetterService.new(user)
      pdf = service.get_pdf

      expect(pdf).to be_a(String)
      expect(pdf).to include('%PDF-1.6')
    end
  end
end
