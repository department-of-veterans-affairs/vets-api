# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::DisabilityCompensationController, type: :controller do
  describe 'action method coverage' do
    let(:controller) { described_class.new }

    describe '#submit (lines 38-43)' do
      it 'covers submit method flow' do
        # Mock dependencies
        auto_claim = create(:auto_established_claim)
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(true) # Skip processing

        # Mock render
        allow(controller).to receive(:render)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, url_for: 'http://example.com')

        # Call the method
        controller.send(:submit)

        # Verify render was called
        expect(controller).to have_received(:render)
      end

      it 'processes claim when load testing disabled' do
        auto_claim = create(:auto_established_claim)
        allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return(false)
        allow(controller).to receive(:process_claim)
        allow(controller).to receive(:render)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, url_for: 'http://example.com')

        controller.send(:submit)

        expect(controller).to have_received(:process_claim).with(auto_claim)
      end
    end

    describe '#attachments (lines 53-69)' do
      it 'handles too many attachments' do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new(
            'attachment1' => 'file1', 'attachment2' => 'file2', 'attachment3' => 'file3',
            'attachment4' => 'file4', 'attachment5' => 'file5', 'attachment6' => 'file6',
            'attachment7' => 'file7', 'attachment8' => 'file8', 'attachment9' => 'file9',
            'attachment10' => 'file10', 'attachment11' => 'file11'
          )
        )

        expect do
          controller.send(:attachments)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity, /Too many attachments/)
      end

      it 'handles claim not found' do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new('id' => '999', 'attachment1' => 'file')
        )
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).with('999').and_return(nil)

        expect do
          controller.send(:attachments)
        end.to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::ResourceNotFound, /Resource not found/)
      end

      it 'processes documents when claim exists' do
        claim = create(:auto_established_claim)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:get_by_id_or_evss_id).with(claim.id).and_return(claim)

        documents_service = instance_double(ClaimsApi::V2::DisabilityCompensationDocuments)
        allow(documents_service).to receive(:process_documents)
        allow(controller).to receive(:render)
        allow(controller).to receive_messages(
          params: ActionController::Parameters.new('id' => claim.id, 'attachment1' => 'file'),
          documents_service:,
          url_for: 'http://example.com'
        )

        controller.send(:attachments)

        expect(documents_service).to have_received(:process_documents)
        expect(controller).to have_received(:render)
      end
    end

    describe '#synchronous (lines 108-112)' do
      it 'covers synchronous method flow' do
        auto_claim = create(:auto_established_claim, status: ClaimsApi::AutoEstablishedClaim::PENDING)

        docker_service = instance_double(ClaimsApi::DisabilityCompensation::DockerContainerService)
        allow(docker_service).to receive(:upload)

        allow(controller).to receive(:queue_flash_updater)
        allow(controller).to receive(:start_bd_uploader_job)
        allow(controller).to receive(:render)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: true, veteran_middle_initial: 'M',
                                              docker_container_service: docker_service,
                                              url_for: 'http://example.com')

        controller.send(:synchronous)

        expect(docker_service).to have_received(:upload).with(auto_claim.id)
        expect(controller).to have_received(:queue_flash_updater).with(auto_claim.flashes, auto_claim.id)
        expect(controller).to have_received(:start_bd_uploader_job).with(auto_claim)
      end

      it 'calls generate_pdf_from_service when not mocking' do
        auto_claim = create(:auto_established_claim)
        allow(controller).to receive(:generate_pdf_from_service!)

        docker_service = instance_double(ClaimsApi::DisabilityCompensation::DockerContainerService)
        allow(docker_service).to receive(:upload)

        allow(controller).to receive(:queue_flash_updater)
        allow(controller).to receive(:start_bd_uploader_job)
        allow(controller).to receive(:render)
        allow(controller).to receive_messages(shared_submit_methods: auto_claim, claims_load_testing: false,
                                              mocking: false, veteran_middle_initial: 'M',
                                              docker_container_service: docker_service,
                                              url_for: 'http://example.com')

        controller.send(:synchronous)

        expect(controller).to have_received(:generate_pdf_from_service!).with(auto_claim.id, 'M')
      end
    end
  end
end
