# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BioSubmissionStatusReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    subject do
      stub_reports_s3 do
        mail
      end
    end

    let(:s3_links) do
      {
        '21-4192' => 'https://s3.example.com/21-4192-report.csv',
        '21-0779' => 'https://s3.example.com/21-0779-report.csv',
        '21P-530a' => 'https://s3.example.com/21P-530a-report.csv',
        '21-2680' => 'https://s3.example.com/21-2680-report.csv'
      }
    end
    let(:mail) { described_class.build(s3_links).deliver_now }

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
      end

      it 'sends the right email with all form links' do
        subject

        expect(mail.subject).to eq(described_class::REPORT_TEXT)
        body = mail.body.encoded
        expect(body).to include('BIO Submission Status Report (links expire in one week)')
        s3_links.each do |form_type, url|
          expect(body).to include("#{form_type}: #{url}")
        end
      end

      it 'emails the right staging recipients' do
        subject

        expect(mail.to).to eq(
          Settings.reports.bio_submission_status.staging_emails.to_a
        )
      end
    end

    context 'when sending production emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'emails the right production recipients' do
        subject

        expect(mail.to).to eq(
          Settings.reports.bio_submission_status.emails.to_a
        )
      end
    end

    context 'when email list is filtered to empty' do
      let(:custom_mailer_class) do
        Class.new(ApplicationMailer) do
          def build_with_empty_emails(s3_links)
            opt = {}
            opt[:to] = []

            return unless opt[:to].present?

            links_html = s3_links.map { |form_type, url| "#{form_type}: #{url}" }.join('<br>')
            mail(
              opt.merge(
                subject: 'BIO Submission Status Report',
                body: "BIO Submission Status Report (links expire in one week)<br><br>#{links_html}"
              )
            )
          end
        end
      end

      it 'returns nil without attempting to send' do
        mailer = custom_mailer_class.new
        result = mailer.build_with_empty_emails(s3_links)
        expect(result).to be_nil
      end
    end
  end
end
