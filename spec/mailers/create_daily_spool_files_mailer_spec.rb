# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateDailySpoolFilesMailer, type: %i[mailer aws_helpers] do
  describe 'with RPO' do
    subject do
      described_class.build('eastern').deliver_now
    end

    # Commented out until email addreses are added back to Settings.edu.spool_error.staging_emails
    # context 'when sending staging emails' do
    #   before do
    #     expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
    #   end
    #
    #   it 'sends the right email' do
    #     date = Time.zone.now.strftime('%m%d%Y')
    #     rpo_name = EducationForm::EducationFacility.rpo_name(region: 'eastern')
    #     body = "There was an error generating the spool file for #{rpo_name} on #{date}"
    #     subject_txt = "Error Generating Spool file on #{date}"
    #     expect(subject.body.raw_source).to eq(body)
    #     expect(subject.subject).to eq(subject_txt)
    #   end
    #   it 'emails the the right staging recipients' do
    #     expect(subject.to).to eq([])
    #   end
    # end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the the right recipients' do
        expect(subject.to).to eq(
          %w[
            Joseph.Preisser@va.gov
            Shay.Norton-Leonard@va.gov
            PIERRE.BROWN@va.gov
            VAVBAHIN/TIMS@vba.va.gov
            EDUAPPMGMT.VBACO@VA.GOV
          ]
        )
      end
    end
  end

  describe 'without RPO' do
    subject do
      described_class.build.deliver_now
    end

    before do
      expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
    end

    it 'has correct body' do
      date = Time.zone.now.strftime('%m%d%Y')
      body = "There was an error generating the spool files on #{date}"
      expect(subject.body.raw_source).to eq(body)
    end
  end
end
