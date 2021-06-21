# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::DecisionReviewMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(date_from: 7.days.ago, date_to: Time.zone.now, friendly_duration: 'duration',
                            recipients: recipients).deliver_now
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
  end
end
