# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/form526_historical_data_exporter/queuer'

RSpec.describe Sidekiq::Form526HistoricalDataExporter::Queuer, type: :job do
  subject { described_class }

  describe 'queue_chunks' do
    let(:user) { create(:user, :loa3) }
    let(:auth_headers) do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    end

    context 'with submission after exporter start_date' do
      let(:saved_claim) { create(:va526ez) }
      let(:submission) do
        create(:form526_submission,
               user_uuid: user.uuid,
               auth_headers_json: auth_headers.to_json,
               saved_claim_id: saved_claim.id)
      end

      let(:data_job_mock) do
        data_job = instance_double(Sidekiq::Form526HistoricalDataExporter::Form526BackgroundDataJob)
        allow(Sidekiq::Form526HistoricalDataExporter::Form526BackgroundDataJob).to receive(:perform_async)
        data_job
      end

      before do
        submission.created_at = '2003-01-03 00:12:34'
        submission.save
      end

      it 'gets one form526submission' do
        start_date = '1/2/2003'
        job_queuer = subject.new(1, 1, start_date)
        expect(job_queuer).to receive(:data_job_wrapper).once
        job_queuer.export
      end

      it 'gets one form526submission with start+end dates' do
        start_date = '1/2/2003'
        end_date = '1/4/2003'
        job_queuer = subject.new(1, 1, start_date, end_date)
        expect(job_queuer).to receive(:data_job_wrapper).once
        job_queuer.export
      end

      it 'does not get submission outside date range' do
        start_date = '1/4/2003'
        end_date = '1/5/2003'
        job_queuer = subject.new(1, 1, start_date, end_date)
        expect(job_queuer).not_to receive(:data_job_wrapper)
        job_queuer.export
      end

      context 'a second submission' do
        let(:saved_claim2) { create(:va526ez) }
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
          start_date = '1/2/2003'
          job_queuer = subject.new(1, 1, start_date)
          expect(job_queuer).to receive(:data_job_wrapper).twice
          job_queuer.export
        end
      end
    end
  end
end
