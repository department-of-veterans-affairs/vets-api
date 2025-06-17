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
      VCR.use_cassette('bgs/people_service/person_data') do
        VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
          service = DebtsApi::V0::OneDebtLetterService.new(user)
          expect(service).not_to receive(:combine_pdfs)
          pdf = service.get_pdf

          expect(pdf).to be_a(String)
          expect { CombinePDF.parse(pdf) }.not_to raise_error
        end
      end
    end

    context 'combining PDFs' do
      it 'returns a combined pdf when a document is provided' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = DebtsApi::V0::OneDebtLetterService.new(user)
            mock_pdf = StringIO.new('%PDF-1.6 mock pdf content')
            expect(service).to receive(:combine_pdfs).with(mock_pdf)
            service.get_pdf(mock_pdf)
          end
        end
      end
    end
  end
end
