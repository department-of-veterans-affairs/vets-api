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
        allow(client_stub).to receive(:all_claims) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.create(:evss_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryBot.build(:evss_claim, user_uuid: user.uuid)
        updated_claim, synchronized = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end

  describe '#client' do
    context 'when a user is beta registered for common client' do
      it 'should return the common client service' do
        BetaRegistration.create!(user_uuid: user.uuid, feature: described_class::EVSS_COMMON_CLIENT_KEY)
        expect(claim_service.send(:client).is_a?(EVSS::Claims::Service)).to eq(true)
      end
    end

    context 'when user isnt beta registered' do
      it 'should return the legacy service' do
        expect(claim_service.send(:client).is_a?(EVSS::ClaimsService)).to eq(true)
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

    def self.test_log_error
      it 'logs an error to sentry' do
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry).once.with(
          Breakers::OutageException,
          {},
          backend_service: :evss
        )
        subject
      end
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

      test_log_error
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

      test_log_error
    end
  end
end
