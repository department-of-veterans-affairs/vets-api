# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::DisabilityCompensationController, type: :controller do
  let(:controller) { described_class.new }
  let(:auto_claim) { create(:auto_established_claim) }

  describe 'baseline coverage for existing methods' do
    # Action methods
    describe '#submit' do
      it 'handles submit flow' do
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(true)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, render: nil,
                                              url_for: 'http://example.com')
        controller.send(:submit)
        expect(controller).to have_received(:render)
      end

      it 'processes claim when not load testing' do
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(false)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, process_claim: nil,
                                              render: nil, url_for: 'http://example.com')
        controller.send(:submit)
        expect(controller).to have_received(:process_claim)
      end
    end

    describe '#attachments' do
      it 'validates attachment count' do
        params = (1..11).to_h { |i| ["attachment#{i}", 'file'] }
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params))
        expect { controller.send(:attachments) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity, /Too many attachments/)
      end

      it 'validates claim exists' do
        allow(controller).to receive(:params).and_return(ActionController::Parameters.new('id' => '999'))
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(nil)
        expect { controller.send(:attachments) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound)
      end

      it 'processes valid request' do
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).and_return(auto_claim)
        service = instance_double(ClaimsApi::V2::DisabilityCompensationDocuments, process_documents: nil)
        allow(controller).to receive_messages(params: ActionController::Parameters.new('id' => '1'),
                                              documents_service: service, render: nil,
                                              url_for: 'http://example.com')
        controller.send(:attachments)
        expect(service).to have_received(:process_documents)
      end
    end

    describe '#synchronous' do
      let(:docker) { instance_double(ClaimsApi::DisabilityCompensation::DockerContainerService, upload: nil) }

      it 'handles synchronous flow' do
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: true, veteran_middle_initial: 'M',
                                              docker_container_service: docker, queue_flash_updater: nil,
                                              start_bd_uploader_job: nil, render: nil,
                                              url_for: 'http://example.com')
        controller.send(:synchronous)
        expect(docker).to have_received(:upload)
      end

      it 'generates PDF when needed' do
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: false, veteran_middle_initial: 'M',
                                              generate_pdf_from_service!: nil, docker_container_service: docker,
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

      it '#docker_container_service' do
        expect(controller.send(:docker_container_service))
          .to be_a(ClaimsApi::DisabilityCompensation::DockerContainerService)
      end

      it '#queue_flash_updater' do
        expect(ClaimsApi::FlashUpdater).to receive(:perform_async).with(['flash'], '123')
        controller.send(:queue_flash_updater, ['flash'], '123')
      end

      it '#queue_flash_updater skips empty' do
        expect(controller.send(:queue_flash_updater, [], '123')).to be_nil
      end

      it '#start_bd_uploader_job' do
        expect(ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader)
          .to receive(:perform_async).with('456')
        controller.send(:start_bd_uploader_job, double(id: '456'))
      end

      it '#errored_state_value' do
        expect(controller.send(:errored_state_value)).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
      end

      it '#bd_service' do
        expect(controller.send(:bd_service))
          .to eq(ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader)
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

      it '#documents_service' do
        expect(controller.send(:documents_service, {}, auto_claim))
          .to be_a(ClaimsApi::V2::DisabilityCompensationDocuments)
      end

      it '#process_claim' do
        allow(controller).to receive(:veteran_middle_initial).and_return('M')
        expect(ClaimsApi::V2::DisabilityCompensationPdfGenerator).to receive(:perform_async).with('456', 'M')
        controller.send(:process_claim, double(id: '456'))
      end

      it '#shared_submit_methods error handling' do
        allow(controller).to receive_messages(auth_headers: {},
                                              form_attributes: { 'disabilities' => [] },
                                              claim_transaction_id: '123',
                                              flashes: [],
                                              token: double(payload: {}),
                                              target_veteran: double(mpi: double(icn: '123')))
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:create)
          .and_return(double(errors: double(present?: true, messages: { base: ['error'] }), id: nil))
        expect { controller.send(:shared_submit_methods) }
          .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity)
      end

      it '#find_claim' do
        existing = create(:auto_established_claim, md5: 'test-md5')
        claim = ClaimsApi::AutoEstablishedClaim.new(md5: 'test-md5', form_data: {})
        claim.errors.add(:md5, :taken)
        allow(claim).to receive(:new_record?).and_return(true)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).with(md5: 'test-md5').and_return(existing)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find_by).with(header_hash: anything).and_return(nil)
        expect(controller.send(:find_claim, claim).id).to eq(existing.id)
      end
    end

    # NOTE: Intentionally NOT testing shared_validation with FES flipper logic
    # That will be covered in the actual PR with the FES changes
  end
end
