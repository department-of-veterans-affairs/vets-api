# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::WeeklyErrorReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(friendly_duration: 'Weekly',
                            recipients:).deliver_now
    end

    let(:recipients) do
      %w[kelly@adhocteam.us laura.trager@adhocteam.us drew.fisher@adhocteam.us jack.schuss@oddball.io]
    end

    it 'sends the email' do
      with_settings(Settings, vsp_environment: 'mary Poppins') do
        complete_nod = create(:notice_of_disagreement)
        complete_hlr = create(:higher_level_review_v2)
        complete_sc  = create(:supplemental_claim)

        errored_nod = create(:notice_of_disagreement, :status_error)
        errored_hlr = create(:higher_level_review_v2, :status_error)
        errored_sc =  create(:supplemental_claim, :status_error)

        stuck_nod = create(:notice_of_disagreement, created_at: 1.year.ago)
        stuck_hlr = create(:higher_level_review_v2, created_at: 1.year.ago)
        stuck_sc  = create(:supplemental_claim, created_at: 1.year.ago)

        stuck_errored_nod = create(:notice_of_disagreement, created_at: 1.year.ago)
        stuck_errored_hlr = create(:higher_level_review_v2, created_at: 1.year.ago)
        stuck_errored_sc  = create(:supplemental_claim, created_at: 1.year.ago)

        Timecop.freeze(6.months.ago) do
          stuck_nod.update_status! status: :processing
          stuck_hlr.update_status! status: :processing
          stuck_sc.update_status! status: :processing
          stuck_errored_nod.update_status! status: :error
          stuck_errored_hlr.update_status! status: :error
          stuck_errored_sc.update_status! status: :error
        end

        expect(subject.subject).to eq 'Weekly Error Decision Review API report (Mary Poppins)'

        expect(subject.body.decoded).to include('AppealType, Guid, Source, Status, CreatedAt, UpdatedAt').once
        expect(subject.body.decoded).to include(errored_nod.id).once
        expect(subject.body.decoded).to include(errored_hlr.id).once
        expect(subject.body.decoded).to include(errored_sc.id).once

        expect(subject.body.decoded).to include(stuck_nod.id).once
        expect(subject.body.decoded).to include(stuck_hlr.id).once
        expect(subject.body.decoded).to include(stuck_sc.id).once

        expect(subject.body.decoded).to include(stuck_errored_nod.id).once
        expect(subject.body.decoded).to include(stuck_errored_hlr.id).once
        expect(subject.body.decoded).to include(stuck_errored_sc.id).once

        expect(subject.body.decoded).not_to include(complete_nod.id)
        expect(subject.body.decoded).not_to include(complete_hlr.id)
        expect(subject.body.decoded).not_to include(complete_sc.id)
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
          %w[kelly@adhocteam.us laura.trager@adhocteam.us drew.fisher@adhocteam.us jack.schuss@oddball.io]
        )
      end
    end
  end
end
