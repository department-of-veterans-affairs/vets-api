# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::DailyErrorReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      recipients = %w[
        drew.fisher@adhocteam.us
        jack.schuss@oddball.io
        kelly@adhocteam.us
        laura.trager@adhocteam.us
        nathan.wright@oddball.io
      ]
      described_class.build(recipients:).deliver_now
    end

    it 'sends the email' do
      with_settings(Settings, vsp_environment: 'mary Poppins') do
        errored_nod = create(:notice_of_disagreement, :status_error)
        stuck_errored_nod = create(:notice_of_disagreement, created_at: 1.year.ago)

        Timecop.freeze(6.months.ago) do
          Sidekiq::Testing.inline! do
            stuck_errored_nod.update_status! status: :error
          end
        end

        expect(subject.subject).to eq 'Daily Error Decision Review API report (Mary Poppins)'
        expect(subject.body.decoded).to include(errored_nod.id).once
        expect(subject.body.decoded).to include(stuck_errored_nod.id).once
      end
    end

    it "doesn't send the email if there are no errors" do
      with_settings(Settings, vsp_environment: 'mary Poppins') do
        expect(subject).to be_nil
      end
    end

    it 'sends to the right people' do
      with_settings(Settings, vsp_environment: 'mary Poppins') do
        create(:notice_of_disagreement, :status_error)
        expect(subject.to).to match_array(
          %w[
            kelly@adhocteam.us
            laura.trager@adhocteam.us
            drew.fisher@adhocteam.us
            jack.schuss@oddball.io
            nathan.wright@oddball.io
          ]
        )
      end
    end
  end
end
