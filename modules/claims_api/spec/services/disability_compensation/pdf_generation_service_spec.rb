# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require './modules/claims_api/app/services/claims_api/disability_compensation/pdf_generation_service'

describe ClaimsApi::DisabilityCompensation::PdfGenerationService do
  let(:pdf_generation_service) { described_class.new }
  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }
  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end
  let(:claim) do
    claim = create(:auto_established_claim, :pending, form_data:)
    claim.auth_headers = auth_headers
    claim.transaction_id = '00000000-0000-0000-000000000000'
    claim.save
    claim
  end
  let(:middle_initial) { ' ' }
  let(:mapped_claim) do
    { data: { attributes: { claimProcessType: 'STANDARD_CLAIM_PROCESS' } } }
  end

  describe '#generate' do
    it 'returns the claim status' do
      VCR.use_cassette('claims_api/pdf_client') do
        allow(pdf_generation_service).to receive(:generate_mapped_claim).with(claim,
                                                                              middle_initial).and_return(mapped_claim)

        expect(pdf_generation_service.send(:generate, claim.id, middle_initial)).to eq('pending')
      end
    end

    it 'logs the transaction_id' do
      VCR.use_cassette('claims_api/pdf_client') do
        allow(Rails.logger).to receive(:info)
        allow(pdf_generation_service).to receive(:generate_mapped_claim).with(claim,
                                                                              middle_initial).and_return(mapped_claim)
        pdf_generation_service.send(:generate, claim.id, middle_initial)
        expect(Rails.logger).to have_received(:info).with(/#{claim.transaction_id}/).at_least(:once)
      end
    end

    context 'when the pdf string is empty' do
      before do
        allow(pdf_generation_service).to receive(:generate_mapped_claim).with(claim,
                                                                              middle_initial).and_return(mapped_claim)
        allow(pdf_generation_service).to receive(:generate_526_pdf).with(mapped_claim).and_return('')
      end

      it 'returns the errored claim status' do
        VCR.use_cassette('claims_api/pdf_client') do
          expect(pdf_generation_service.send(:generate, claim.id, middle_initial)).to eq('errored')
        end
      end
    end
  end
end
