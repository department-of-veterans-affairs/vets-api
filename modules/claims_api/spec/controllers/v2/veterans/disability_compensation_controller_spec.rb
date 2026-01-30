# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::DisabilityCompensationController, type: :controller do
  let(:controller) { described_class.new }
  let(:auto_claim) { create(:auto_established_claim) }

  describe 'baseline coverage for existing methods' do
    # Action methods

    describe '#synchronous' do
      let(:docker) { instance_double(ClaimsApi::DisabilityCompensation::Form526EstablishmentService, upload: nil) }

      it 'handles synchronous flow' do
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: true, veteran_middle_initial: 'M',
                                              form526_establishment_service: docker, queue_flash_updater: nil,
                                              start_bd_uploader_job: nil, render: nil,
                                              url_for: 'http://example.com')
        controller.send(:synchronous)
        expect(docker).to have_received(:upload)
      end

      it 'generates PDF when needed' do
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: false, veteran_middle_initial: 'M',
                                              generate_pdf_from_service!: nil, form526_establishment_service: docker,
                                              queue_flash_updater: nil, start_bd_uploader_job: nil,
                                              render: nil, url_for: 'http://example.com')
        controller.send(:synchronous)
        expect(controller).to have_received(:generate_pdf_from_service!)
      end
    end

    # Helper methods
    describe 'private helpers' do
      it '#save_auto_claim!' do
        allow(auto_claim).to receive(:save!)
        controller.send(:save_auto_claim!, auto_claim)
        expect(auto_claim.validation_method).to eq(ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD)
      end

      it '#pdf_generation_service' do
        expect(controller.send(:pdf_generation_service))
          .to be_a(ClaimsApi::DisabilityCompensation::PdfGenerationService)
      end

      it '#form526_establishment_service' do
        expect(controller.send(:form526_establishment_service))
          .to be_a(ClaimsApi::DisabilityCompensation::Form526EstablishmentService)
      end

      it '#queue_flash_updater' do
        expect(ClaimsApi::FlashUpdater).to receive(:perform_async).with(['flash'], '123')
        controller.send(:queue_flash_updater, ['flash'], '123')
      end

      it '#queue_flash_updater skips empty' do
        expect(controller.send(:queue_flash_updater, [], '123')).to be_nil
      end

      it '#start_bd_uploader_job' do
        expect(ClaimsApi::DisabilityCompensationBenefitsDocumentsUploader)
          .to receive(:perform_async).with('456')
        controller.send(:start_bd_uploader_job, double(id: '456'))
      end

      it '#errored_state_value' do
        expect(controller.send(:errored_state_value)).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
      end

      it '#bd_service' do
        expect(controller.send(:bd_service))
          .to eq(ClaimsApi::DisabilityCompensationBenefitsDocumentsUploader)
      end

      it '#sandbox_request' do
        expect(controller.send(:sandbox_request, double(base_url: 'https://sandbox-api.va.gov'))).to be true
      end

      it '#claims_load_testing' do
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(true)
        expect(controller.send(:claims_load_testing)).to be true
      end

      it '#mocking' do
        with_settings(Settings.claims_api.benefits_documents, use_mocks: true) do
          expect(controller.send(:mocking)).to be true
        end
      end

      it '#generate_pdf_from_service! error handling' do
        service = instance_double(ClaimsApi::DisabilityCompensation::PdfGenerationService)
        allow(controller).to receive(:pdf_generation_service).and_return(service)
        allow(service).to receive(:generate).and_return(ClaimsApi::AutoEstablishedClaim::ERRORED)
        expect { controller.send(:generate_pdf_from_service!, '123', 'M') }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity)
      end

      it '#shared_submit_methods error handling' do
        allow(controller).to receive_messages(auth_headers: {},
                                              form_attributes: { 'disabilities' => [] },
                                              claim_transaction_id: '123',
                                              flashes: [],
                                              token: double(payload: {}),
                                              target_veteran: double(mpi: double(icn: '123')))
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:create)
          .and_return(double(
                        errors: double(present?: true,
                                       messages: { base: ['error'] }), id: nil
                      ))
        expect { controller.send(:shared_submit_methods) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity)
      end

      it '#find_claim' do
        # Returns existing persisted claim when header_hash matches
        persisted_claim = create(:auto_established_claim)

        new_claim = ClaimsApi::AutoEstablishedClaim.new(
          header_hash: persisted_claim.header_hash,
          form_data: {}
        )

        expect(controller.send(:find_claim, new_claim)).to eq(persisted_claim)

        # Returns input claim when no match found
        unmatched_claim = ClaimsApi::AutoEstablishedClaim.new(header_hash: 'different-hash', form_data: {})
        expect(controller.send(:find_claim, unmatched_claim)).to eq(unmatched_claim)
      end
    end

    # NOTE: Intentionally NOT testing shared_validation with FES flipper logic
    # That will be covered in the actual PR with the FES changes
  end
end
