# frozen_string_literal: true

require 'rails_helper'

RSpec.describe YearToDateReportMailer, type: %i[mailer aws_helpers] do
  describe '#year_to_date_report_email' do
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    let(:filename) { 'foo' }
    let(:mail) { described_class.build(filename).deliver_now }

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
      end

      it 'sends the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
        expect(mail.subject).to eq(text)
      end

      it 'emails the the right staging recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            Brian.Grubb@va.gov
            Joseph.Preisser@va.gov
            kyle.pietrosanto@va.gov
            lee.munson@va.gov
            lihan@adhocteam.us
            Lucas.Tickner@va.gov
            matthew.ziolkowski@va.gov
            Michael.Johnson19@va.gov
            patrick.burk@va.gov
            preston.sanders@va.gov
            robyn.noles@va.gov
            Ricardo.DaSilva@va.gov
            tammy.hurley1@va.gov
            abelardo.blanco@va.gov
            eugenia.gina.ronat@accenturefederal.com
            morgan.whaley@accenturefederal.com
            m.c.shah@accenturefederal.com
            d.a.barnes@accenturefederal.com
            jacob.finnern@accenturefederal.com
            hocine.halli@accenturefederal.com
            adam.freemer@accenturefederal.com
          ]
        )
      end
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the va stakeholders' do
        subject
        expect(mail.to).to eq(
          %w[
            222A.VBAVACO@va.gov
            224B.VBAVACO@va.gov
            224C.VBAVACO@va.gov
            Brandon.Scott2@va.gov
            Brian.Grubb@va.gov
            Christina.DiTucci@va.gov
            EDU.VBAMUS@va.gov
            John.McNeal@va.gov
            Joseph.Preisser@va.gov
            Joshua.Lashbrook@va.gov
            kathleen.dalfonso@va.gov
            kyle.pietrosanto@va.gov
            Lucas.Tickner@va.gov
            michele.mendola@va.gov
            Ricardo.DaSilva@va.gov
            shay.norton@va.gov
            tammy.hurley1@va.gov
          ]
        )
      end
    end
  end
end
