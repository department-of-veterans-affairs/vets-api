# frozen_string_literal: true

require 'rails_helper'
RSpec.describe PreneedsSubmissionsReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(
        start_date: '2019-02-15',
        end_date: '2019-02-21',
        successes_count: 111,
        error_persisting_count: 2,
        server_unavailable_count: 1,
        other_errors_count: 0
      ).deliver_now
    end

    it 'sends the right email' do
      expect(subject.body.raw_source).to eq(File.read('spec/fixtures/preneeds/preneeds_submission_report.html'))
      expect(subject.subject).to eq('Preneeds submissions report')
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the the right recipients' do
        expect(subject.to).to eq(
          %w[
            johnny@oddball.io
            Ronald.Newcomb@va.gov
            Anthony.Tignola@va.gov
            Ashutosh.Shah@va.gov
            Caroline.Javornisky@va.gov
            Dale.Beehler@va.gov
          ]
        )
      end
    end
  end
end
