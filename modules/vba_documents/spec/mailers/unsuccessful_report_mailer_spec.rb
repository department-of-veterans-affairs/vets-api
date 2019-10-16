# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UnsuccessfulReportMailer, type: [:mailer] do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }

  describe '#build' do
    subject do
      described_class.build([error_upload], 7.days.ago, Time.zone.now).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Intake Unsuccessful Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          andrew.fichter@va.gov
          michael.bastos@oddball.io
          charley.stran@oddball.io
          alex.teal@oddball.io
          ryan.link@oddball.io
          aubrey.suter@adhocteam.us
          trista.rowan@adhocteam.us
        ]
      )
    end
  end
end
