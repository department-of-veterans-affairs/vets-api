# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSSClaimService do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  let(:service) { described_class.new(user) }
  subject { service }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims).and_raise(Common::Exceptions::BackendServiceException.new('EVSS502'))
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id).and_raise(Common::Exceptions::BackendServiceException.new('EVSS502'))
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.build(:evss_claim, user_uuid: user.uuid)
        updated_claim, synchronized = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end

  describe '#upload_document' do
    let(:tempfile) do
      f = Tempfile.new(['file with spaces', '.txt'])
      f.write('test')
      f.rewind
      f
    end
    let(:document) do
      EVSSClaimDocument.new(
        tracked_item_id: 1,
        file_obj: tempfile,
        file_name: File.basename(tempfile.path)
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
      expect(doc_args['file_name']).to match(/file_with_spaces.*\.txt/)
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
      let(:claim) { FactoryBot.build(:evss_claim, user_uuid: user.uuid) }
      subject do
        service.update_from_remote(claim)
      end

      it 'returns claim' do
        updated_claim, synchronized = subject
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end
end
