# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module SupportingEvidence
    RSpec.describe EvidenceUploader do
      let(:appeal) { create(:notice_of_disagreement) }

      describe '#process!' do
        let(:uploader) { EvidenceUploader.new(appeal, nil, type: :notice_of_disagreement) }
        let(:double) { instance_double('TemporaryStorageUploader') }

        before do
          allow(double).to receive(:store!).and_return(true)
          allow(double).to receive(:filename)
          allow(TemporaryStorageUploader).to receive(:new).and_return(double)
        end

        it 'generates an EvidenceSubmission record' do
          expect(appeal.evidence_submissions.count).to eq(0)

          uploader.process!

          expect(appeal.evidence_submissions.count).to eq(1)
        end

        it 'calls store! for CarrierWave' do
          uploader.process!

          expect(double).to have_received(:store!)
        end

        it 'handles errors on upload' do
          allow(double).to receive(:store!).and_raise(RuntimeError)
          allow(uploader).to receive(:log_message_to_sentry)

          expect { uploader.process! }.to raise_error(RuntimeError)
          evidence = appeal.evidence_submissions.first
          expect(uploader).to have_received(:log_message_to_sentry)
            .with(
              'Error saving to S3',
              :warning,
              error: 'RuntimeError',
              evidence_guid: evidence.id,
              supportable_id: evidence.supportable_id,
              supportable_type: evidence.supportable_type
            )
          expect(evidence.status).to eq('error')
          expect(evidence.code).to eq('RuntimeError')
          expect(evidence.details).to eq('RuntimeError')
        end

        it 'marks the created submission \'submitted\'' do
          uploader.process!
          expect(appeal.evidence_submissions.first.status).to eq('submitted')
        end
      end
    end
  end
end
