# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::DecisionReviewMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(date_from: 7.days.ago, date_to: Time.zone.now, friendly_duration: 'duration',
                            recipients:).deliver_now
    end

    let(:recipients) do
      %w[
        kelly@adhocteam.us
        laura.trager@adhocteam.us
        drew.fisher@adhocteam.us
        jack.schuss@oddball.io
        nathan.wright@oddball.io
      ]
    end

    it 'sends the email' do
      with_settings(Settings, vsp_environment: 'spartacus') do
        expect(subject.subject).to eq 'duration Decision Review API report (Spartacus)'
      end
    end

    it 'sends to the right people' do
      with_settings(Settings, vsp_environment: 'spartacus') do
        expect(subject.to).to match_array(recipients)
      end
    end

    it 'displays totals on weekly report' do
      create(:notice_of_disagreement, status: 'complete', created_at: 3.weeks.ago)
      create_list(:supplemental_claim, 2, status: 'complete', created_at: 3.weeks.ago)

      mail = described_class.build(date_from: 7.days.ago, date_to: Time.zone.now, friendly_duration: 'Weekly',
                                   recipients:).deliver_now

      body = mail.body.to_s
      expect(body).to include 'Total HLR: 0'
      expect(body).to include 'Total NOD: 1'
      expect(body).to include 'Total SC: 2'
    end

    it 'displays more useful info on faulty evidence submissions' do
      es = create(:evidence_submission_with_error)
      mail = described_class.build(date_from: 7.days.ago, date_to: Time.zone.now, friendly_duration: 'Weekly',
                                   recipients:).deliver_now
      body = mail.body.to_s
      expect(body).to include es.guid
      expect(body).to include es.supportable_id
      expect(body).to include es.upload_submission.guid
      expect(body).to include es.upload_submission.detail
    end
  end
end
