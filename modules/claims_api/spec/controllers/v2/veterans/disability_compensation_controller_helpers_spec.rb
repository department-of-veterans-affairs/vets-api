# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::DisabilityCompensationController, type: :controller do
  describe 'additional helper methods' do
    let(:controller) { described_class.new }

    describe '#generate_pdf_from_service!' do
      it 'raises error when PDF generation returns ERRORED' do
        pdf_service = instance_double(ClaimsApi::DisabilityCompensation::PdfGenerationService)
        allow(controller).to receive(:pdf_generation_service).and_return(pdf_service)
        allow(pdf_service).to receive(:generate).and_return(ClaimsApi::AutoEstablishedClaim::ERRORED)

        expect do
          controller.send(:generate_pdf_from_service!, '123', 'M')
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity)
      end
    end

    describe '#documents_service' do
      it 'returns DisabilityCompensationDocuments instance' do
        params = { test: 'params' }
        claim = double('claim')

        service = controller.send(:documents_service, params, claim)
        expect(service).to be_a(ClaimsApi::V2::DisabilityCompensationDocuments)
      end
    end

    describe '#process_claim' do
      it 'performs async PDF generation' do
        claim = double(id: '456')
        allow(controller).to receive(:veteran_middle_initial).and_return('M')

        expect(ClaimsApi::V2::DisabilityCompensationPdfGenerator).to receive(:perform_async).with('456', 'M')
        controller.send(:process_claim, claim)
      end
    end

    describe '#shared_submit_methods with errors' do
      it 'raises UnprocessableEntity when auto_claim has errors' do
        allow(controller).to receive_messages(auth_headers: {}, form_attributes: { 'disabilities' => [] },
                                              claim_transaction_id: '123', flashes: [],
                                              token: double(payload: {}),
                                              target_veteran: double(mpi: double(icn: '123')))

        # Force error on create
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:create).and_return(
          double(errors: double(present?: true, messages: { base: ['error'] }), id: nil)
        )

        expect do
          controller.send(:shared_submit_methods)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity)
      end
    end

    describe '#shared_validation with validation errors' do
      it 'raises JsonFormValidationError when validation errors present' do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_enable_FES).and_return(false)
        allow(controller).to receive_messages(validate_json_schema: nil, validate_veteran_name: nil,
                                              target_veteran: double,
                                              validate_form_526_submission_values: [{ detail: 'error' }])

        expect do
          controller.send(:shared_validation)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::JsonFormValidationError)
      end
    end

    describe '#find_claim' do
      it 'finds claim by md5 when duplicate error' do
        existing_claim = create(:auto_established_claim, md5: 'test-md5')
        new_claim = ClaimsApi::AutoEstablishedClaim.new(md5: 'test-md5', form_data: {})
        new_claim.errors.add(:md5, :taken)

        allow(new_claim).to receive(:new_record?).and_return(true)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).with(md5: 'test-md5').and_return(existing_claim)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).with(header_hash: anything).and_return(nil)

        result = controller.send(:find_claim, new_claim)
        expect(result.id).to eq(existing_claim.id)
      end
    end
  end
end
