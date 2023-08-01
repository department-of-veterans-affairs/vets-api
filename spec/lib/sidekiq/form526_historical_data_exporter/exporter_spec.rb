# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/form526_historical_data_exporter/exporter'

RSpec.describe Sidekiq::Form526HistoricalDataExporter::Exporter, type: :job do
  subject { described_class }

  describe 'queue_chunks' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    end

    context 'with submission after exporter start_date' do
      let(:saved_claim) { FactoryBot.create(:va526ez) }
      let(:submission) do
        create(:form526_submission,
               user_uuid: user.uuid,
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id)
      end

      before do
        Flipper.enable(:disability_526_classifier)
        submission.created_at = '2003-01-03 00:12:34'
        submission.save
      end

      it 'gets one form526submission' do
        exporter = subject.new(1, submission.id, submission.id)
        expect(exporter).to receive(:get_submission_stats).once
        expect(exporter).to receive(:upload_to_s3!).once
        exporter.process!
      end

      context 'a second submission' do
        let(:saved_claim2) { FactoryBot.create(:va526ez) }
        let(:submission2) do
          create(:form526_submission,
                 user_uuid: user.uuid,
                 auth_headers_json: auth_headers.to_json,
                 saved_claim_id: saved_claim2.id)
        end

        before do
          submission2.created_at = '2003-01-03 00:12:34'
          submission2.save
        end

        it 'gets two form526submissions' do
          exporter = subject.new(1, submission.id, submission2.id)
          expect(exporter).to receive(:get_submission_stats).twice
          expect(exporter).to receive(:upload_to_s3!).once
          exporter.process!
        end
      end
    end
  end
end
