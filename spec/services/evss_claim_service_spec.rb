# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimService do
  subject { service }

  let(:user) { create(:user, :loa3) }
  let(:user_account) { create(:user_account) }
  let(:client_stub) { instance_double(EVSS::ClaimsService) }
  let(:service) { described_class.new(user) }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims).and_raise(EVSS::ErrorMiddleware::EVSSBackendServiceError)
        allow(subject).to receive(:client) { client_stub }
        claim = create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to be(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id).and_raise(
          EVSS::ErrorMiddleware::EVSSBackendServiceError
        )
        allow(subject).to receive(:client) { client_stub }
        claim = build(:evss_claim, user_uuid: user.uuid)
        updated_claim, synchronized = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(synchronized).to be(false)
      end
    end
  end

  context 'when user is not a Veteran' do
    # Overriding global user / service values
    let(:user) { create(:evss_user, birls_id: nil) }
    let(:service) { described_class.new(user) }
    # rubocop:disable Style/HashSyntax
    let(:claim) { { :benefit_claim_details_dto => { :ptcpnt_vet_id => '234567891' } } }
    # rubocop:enable Style/HashSyntax
    let(:claim_service) { BGS::EbenefitsBenefitClaimsStatus }

    before do
      allow(Rails.logger).to receive(:info)
      allow_any_instance_of(claim_service).to receive(:find_benefit_claim_details_by_benefit_claim_id).and_return(claim)
      user.user_account_uuid = user_account.id
      user.save!
    end

    describe '#request_decision' do
      it 'supplements the headers' do
        claim = build(:evss_claim, user_uuid: user.uuid)
        subject.request_decision(claim)

        job = EVSS::RequestDecision.jobs.last
        job_id = job['jid']
        job_args = job['args'][0]

        header = job_args['va_eauth_pid']
        expect(header).to eq('234567891')

        expect(Rails.logger)
          .to have_received(:info)
          .with('Supplementing EVSS headers', {
                  message_type: 'evss.request_decision.no_birls_id',
                  claim_id: 1,
                  job_id:,
                  revision: 2
                })
      end
    end

    describe '#upload_document' do
      let(:upload_file) do
        f = Tempfile.new(['file with spaces', '.txt'])
        f.write('test')
        f.rewind
        rack_file = Rack::Test::UploadedFile.new(f.path, 'text/plain')

        ActionDispatch::Http::UploadedFile.new(
          tempfile: rack_file.tempfile,
          filename: rack_file.original_filename,
          type: rack_file.content_type
        )
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

        header = job_args['va_eauth_pid']
        expect(header).to eq('234567891')

        expect(Rails.logger)
          .to have_received(:info)
          .with('Supplementing EVSS headers', {
                  message_type: 'evss.document_upload.no_birls_id',
                  claim_id: 1,
                  job_id:,
                  revision: 2
                })
      end
    end
  end

  describe '#upload_document' do
    before do
      user.user_account_uuid = user_account.id
      user.save!
    end

    let(:issue_instant) { Time.current.to_i }
    let(:submitted_date) do
      BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(issue_instant)
    end

    let(:upload_file) do
      f = Tempfile.new(['file with spaces', '.txt'])
      f.write('test')
      f.rewind
      rack_file = Rack::Test::UploadedFile.new(f.path, 'image/jpeg')

      ActionDispatch::Http::UploadedFile.new(
        tempfile: rack_file.tempfile,
        filename: rack_file.original_filename,
        type: rack_file.content_type
      )
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

    context 'when :cst_send_evidence_submission_failure_emails is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(true)
        allow(StatsD).to receive(:increment)
      end

      it 'records evidence submission PENDING' do
        subject.upload_document(document)
        expect(EvidenceSubmission.count).to eq(1)
        evidence_submission = EvidenceSubmission.first
        current_personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
        expect(evidence_submission.upload_status)
          .to eql(BenefitsDocuments::Constants::UPLOAD_STATUS[:CREATED])
        expect(current_personalisation['date_submitted']).to eql(submitted_date)
        expect(StatsD)
          .to have_received(:increment)
          .with('cst.evss.document_uploads.evidence_submission_record_created')
      end
    end

    context 'when :cst_send_evidence_submission_failure_emails is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_send_evidence_submission_failure_emails).and_return(false)
      end

      it 'does not record evidence submission' do
        subject.upload_document(document)
        expect(EvidenceSubmission.count).to eq(0)
      end
    end

    it 'updates document with sanitized filename' do
      subject.upload_document(document)
      job = EVSS::DocumentUpload.jobs.last
      doc_args = job['args'][2]
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
        claim = create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject
        expect(claims).to eq([claim])
        expect(synchronized).to be(false)
      end
    end

    describe '#update_from_remote' do
      subject do
        service.update_from_remote(claim)
      end

      let(:claim) { build(:evss_claim, user_uuid: user.uuid) }

      it 'returns claim' do
        updated_claim, synchronized = subject
        expect(updated_claim).to eq(claim)
        expect(synchronized).to be(false)
      end
    end
  end
end
