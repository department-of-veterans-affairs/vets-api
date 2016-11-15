# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimService do
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  subject { described_class.new(user) }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryGirl.create(:disability_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryGirl.build(:disability_claim, user_uuid: user.uuid)
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
    let(:document) { DisabilityClaimDocument.new(tracked_item_id: 1) }

    it 'enqueues a job' do
      expect do
        subject.upload_document(tempfile, document)
      end.to change(DisabilityClaim::DocumentUpload.jobs, :size).by(1)
    end

    it 'updates document with sanitized filename' do
      subject.upload_document(tempfile, document)
      job = DisabilityClaim::DocumentUpload.jobs.last
      doc_args = job['args'].last
      expect(doc_args['file_name']).to match(/file_with_spaces.*\.txt/)
    end
  end

  context 'when EVSS client has an outage' do
    describe '#all' do
      it 'returns all claims for the user' do
        EVSS::ClaimsService.breakers_service.begin_forced_outage!
        claim = FactoryGirl.create(:disability_claim, user_uuid: user.uuid)
        claims, synchronized = subject.all
        expect(claims).to eq([claim])
        expect(synchronized).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        EVSS::ClaimsService.breakers_service.begin_forced_outage!
        claim = FactoryGirl.build(:disability_claim, user_uuid: user.uuid)
        updated_claim, synchronized = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(synchronized).to eq(false)
      end
    end
  end
end
