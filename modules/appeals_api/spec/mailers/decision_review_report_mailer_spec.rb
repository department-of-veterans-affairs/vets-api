# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::DecisionReviewMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(date_from: 7.days.ago, date_to: Time.zone.now).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Decision Review API report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          premal.shah@va.gov
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
