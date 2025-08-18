# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::DisabilityCompensationController, type: :controller do
  describe 'private methods coverage' do
    let(:controller) { described_class.new }

    describe '#save_auto_claim!' do
      it 'sets validation method and saves' do
        claim = ClaimsApi::AutoEstablishedClaim.new(form_data: { test: 'data' })
        allow(claim).to receive(:save!)
        controller.send(:save_auto_claim!, claim)
        expect(claim.validation_method).to eq(ClaimsApi::AutoEstablishedClaim::VALIDATION_METHOD)
        expect(claim).to have_received(:save!)
      end
    end

    describe '#pdf_generation_service' do
      it 'returns PdfGenerationService instance' do
        service = controller.send(:pdf_generation_service)
        expect(service).to be_a(ClaimsApi::DisabilityCompensation::PdfGenerationService)
      end
    end

    describe '#docker_container_service' do
      it 'returns DockerContainerService instance' do
        service = controller.send(:docker_container_service)
        expect(service).to be_a(ClaimsApi::DisabilityCompensation::DockerContainerService)
      end
    end

    describe '#queue_flash_updater' do
      it 'queues job when flashes present' do
        expect(ClaimsApi::FlashUpdater).to receive(:perform_async).with(['flash'], '123')
        controller.send(:queue_flash_updater, ['flash'], '123')
      end

      it 'returns nil when flashes blank' do
        result = controller.send(:queue_flash_updater, [], '123')
        expect(result).to be_nil
      end
    end

    describe '#start_bd_uploader_job' do
      it 'queues benefits documents uploader' do
        claim = double(id: '456')
        expect(ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader).to receive(:perform_async).with('456')
        controller.send(:start_bd_uploader_job, claim)
      end
    end

    describe '#errored_state_value' do
      it 'returns ERRORED constant' do
        expect(controller.send(:errored_state_value)).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
      end
    end

    describe '#bd_service' do
      it 'returns benefits documents uploader class' do
        expect(controller.send(:bd_service)).to eq(ClaimsApi::V2::DisabilityCompensationBenefitsDocumentsUploader)
      end
    end

    describe '#sandbox_request' do
      it 'returns true for sandbox URL' do
        request = double(base_url: 'https://sandbox-api.va.gov')
        expect(controller.send(:sandbox_request, request)).to be true
      end

      it 'returns false for non-sandbox URL' do
        request = double(base_url: 'https://api.va.gov')
        expect(controller.send(:sandbox_request, request)).to be false
      end
    end

    describe '#claims_load_testing' do
      it 'checks Flipper flag' do
        expect(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(true)
        expect(controller.send(:claims_load_testing)).to be true
      end
    end

    describe '#mocking' do
      it 'returns mocks setting value' do
        with_settings(Settings.claims_api.benefits_documents, use_mocks: true) do
          expect(controller.send(:mocking)).to be true
        end
      end
    end
  end
end
