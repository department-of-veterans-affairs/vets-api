# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UnsuccessfulReportMailer, type: [:mailer] do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }
  let(:uploaded_upload) { FactoryBot.create(:upload_submission, :status_uploaded) }
  let(:totals) do
    [
      {
        'vetraspec' => {
          'error' => 1,
          'expired' => 1,
          'pending' => 4,
          'uploaded' => 1,
          :totals => 7,
          :error_rate => '14%',
          :expired_rate => '14%'
        }
      },
      {
        'vetpro' => {
          'error' => 2,
          'expired' => 1,
          'pending' => 2,
          'uploaded' => 2,
          :totals => 7,
          :error_rate => '29%',
          :expired_rate => '14%'
        }
      }
    ]
  end

  describe '#build' do
    subject do
      described_class.build(totals, [error_upload], [uploaded_upload], 7.days.ago, Time.zone.now).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Intake Unsuccessful Submission Report')
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
          lydia.vian@thunderyard.com
          joshua.jennings@libertyits.com
          cristopher.shupp@libertyits.com
          gregory.bowman@libertyits.com
          zachary.goldfine@va.gov
        ]
      )
    end
  end
end
