# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::DailyErrorReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build.deliver_now
    end

    it 'sends the email' do
      with_settings(Settings, vsp_environment: 'mary Poppins') do
        AppealsApi::Events::Handler.subscribe(:nod_status_updated, 'AppealsApi::Events::StatusUpdated')
        errored_nod = create(:notice_of_disagreement, :status_error)
        stuck_nod = create(:notice_of_disagreement, created_at: 1.year.ago)

        Timecop.freeze(6.months.ago) do
          Sidekiq::Testing.inline! do
            stuck_nod.update_status! status: :processing
          end
        end

        expect(subject.subject).to eq 'Daily Error Decision Review API report (Mary Poppins)'
        expect(subject.body).to include errored_nod.id
        expect(subject.body).to include stuck_nod.id
      end
    end

    it 'sends the email even when there are only stuck records' do
      stuck_nod = create(:notice_of_disagreement, created_at: 1.year.ago)

      Timecop.freeze(6.months.ago) do
        Sidekiq::Testing.inline! do
          stuck_nod.update_status! status: :processing
        end
      end

      expect(subject.body).to include stuck_nod.id
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
