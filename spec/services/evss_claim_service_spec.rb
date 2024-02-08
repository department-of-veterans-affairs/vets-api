# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimService do
  subject { service }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  let(:service) { described_class.new(user) }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims).and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id).and_raise(
          EVSS::ErrorMiddleware::EVSSBackendServiceError
        )
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.build(:evss_claim, user_uuid: user.uuid)
        updated_claim, synchronized = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end

  context 'when user is not a Veteran' do
    # Overriding global user / service values
    let(:user) { FactoryBot.create(:evss_user, birls_id: nil) }
    let(:service) { described_class.new(user) }

    before do
      allow(Rails.logger).to receive(:info)
    end

    describe '#request_decision' do
      it 'supplements the headers' do
        claim = FactoryBot.build(:evss_claim, user_uuid: user.uuid)
        subject.request_decision(claim)

        job = EVSS::RequestDecision.jobs.last
        job_id = job['jid']
        job_args = job['args'][0]

        header = job_args['va_eauth_birlsfilenumber']
        expect(header).to eq(user.ssn)

        expect(Rails.logger)
          .to have_received(:info)
          .with('Supplementing EVSS headers', {
                  message_type: 'evss.request_decision.no_birls_id',
                  claim_id: 1,
                  job_id:
                })
      end
    end

    describe '#upload_document' do
      let(:upload_file) do
        f = Tempfile.new(['file with spaces', '.txt'])
        f.write('test')
        f.rewind
        Rack::Test::UploadedFile.new(f.path, 'image/jpeg')
      end

      let(:document) do
        EVSSClaimDocument.new(
          evss_claim_id: 1,
          tracked_item_id: 1,
          file_obj: upload_file,
          file_name: File.basename(upload_file.path)
        )
      end

      it 'supplements the headers' do
        subject.upload_document(document)

        job = EVSS::DocumentUpload.jobs.last
        job_id = job['jid']
        job_args = job['args'][0]

        header = job_args['va_eauth_birlsfilenumber']
        expect(header).to eq(user.ssn)

        expect(Rails.logger)
          .to have_received(:info)
          .with('Supplementing EVSS headers', {
                  message_type: 'evss.document_upload.no_birls_id',
                  claim_id: 1,
                  job_id:
                })
      end
    end
  end

  describe '#upload_document' do
    let(:upload_file) do
      f = Tempfile.new(['file with spaces', '.txt'])
      f.write('test')
      f.rewind
      Rack::Test::UploadedFile.new(f.path, 'image/jpeg')
    end
    let(:document) do
      EVSSClaimDocument.new(
        tracked_item_id: 1,
        file_obj: upload_file,
        file_name: File.basename(upload_file.path)
      )
    end

    it 'enqueues a job' do
      expect do
        subject.upload_document(document)
      end.to change(EVSS::DocumentUpload.jobs, :size).by(1)
    end

    it 'updates document with sanitized filename' do
      subject.upload_document(document)
      job = EVSS::DocumentUpload.jobs.last
      doc_args = job['args'].last
      expect(doc_args['file_name']).to match(/filewithspaces.*\.txt/)
    end
  end

  context 'when EVSS client has an outage' do
    before do
      EVSS::ClaimsService.breakers_service.begin_forced_outage!
    end

    describe '#all' do
      subject do
        service.all
      end

      it 'returns all claims for the user' do
        claim = FactoryBot.create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      subject do
        service.update_from_remote(claim)
      end

      let(:claim) { FactoryBot.build(:evss_claim, user_uuid: user.uuid) }

      it 'returns claim' do
        updated_claim, synchronized = subject
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end
end
