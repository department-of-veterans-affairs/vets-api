# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  let(:errored_upload) { FactoryBot.create(:auto_established_claim, :status_errored) }
  let(:uploaded_upload) { FactoryBot.create(:auto_established_claim, :status_established) }
  let(:totals) do
    [
      {
        'vetraspec' => {
          'errored' => 1,
          'pending' => 4,
          'uploaded' => 1,
          :totals => 7,
          :error_rate => '14%',
          :expired_rate => '14%'
        }
      },
      {
        'vetpro' => {
          'errored' => 2,
          'pending' => 2,
          'uploaded' => 2,
          :totals => 7,
          :error_rate => '29%'
        }
      }
    ]
  end
  let(:flash_statistics) do
    [
      { flash: 'POW', count: 1, percentage: '50.0%' },
      { flash: 'Homeless', count: 1, percentage: '50.0%' },
      { flash: 'Terminally Ill', count: 1, percentage: '50.0%' }
    ]
  end

  describe '#build' do
    subject do
      described_class.build(7.days.ago, Time.zone.now, consumer_totals: totals,
                                                       unsuccessful_submissions: [errored_upload],
                                                       pending_submissions: [uploaded_upload],
                                                       flash_statistics: flash_statistics).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Unsuccessful Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          david.mazik@va.gov
          michael.bastos@oddball.io
          ryan.link@oddball.io
          christopher.stone@libertyits.com
          valerie.hase@va.gov
          mark.greenburg@adhocteam.us
          premal.shah@va.gov
          lee.deboom@oddball.io
          dan.hinze@adhocteam.us
          seth.johnson@gdit.com
          kayur.shah@gdit.com
          tim.barto@gdit.com
          zachary.goldfine@va.gov
        ]
      )
    end
  end
end
