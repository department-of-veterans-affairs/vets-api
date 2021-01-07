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
    module MailerHelper
      class << self
        attr_reader :env_hash
      end

      @env_hash = {
        staging: 'https://dsva-vetsgov-staging-benefits-documents.s3.us-gov-west-1.amazonaws.com/',
        dev: 'https://dsva-vetsgov-dev-benefits-documents.s3.us-gov-west-1.amazonaws.com/',
        sandbox: 'https://dsva-vagov-sandbox-benefits-documents.s3.us-gov-west-1.amazonaws.com/',
        prod: 'https://dsva-vetsgov-prod-benefits-documents.s3.us-gov-west-1.amazonaws.com/'
      }
    end

    before do
      current_env_url = env_url.last
      Settings.vba_documents.location.prefix = current_env_url
      VBADocuments::Deployment.environment = VBADocuments::Deployment.fetch_environment
      if VBADocuments::UnsuccessfulReportMailer.const_defined?(:RECIPIENTS)
        VBADocuments::UnsuccessfulReportMailer.send(:remove_const, :RECIPIENTS)
      end
      load './modules/vba_documents/app/mailers/vba_documents/unsuccessful_report_mailer.rb'
      @email = described_class.build(totals, [error_upload], [uploaded_upload], 7.days.ago, Time.zone.now).deliver_now
    end

    MailerHelper.env_hash.each_pair do |k, v|
      context 'environments' do
        let(:env_url) { [k, v] }

        it "sends the email for #{k}" do
          expect(@email.subject).to eq("Benefits Intake Unsuccessful Submission Report for #{k}")
        end
      end
    end

    MailerHelper.env_hash.each_pair do |k, v|
      context 'environments' do
        let(:env_url) { [k, v] }

        it "sends to the right people for #{k}" do
          people = VBADocuments::UnsuccessfulReportMailer.fetch_recipients
          expect(@email.to).to eq(people)
        end
      end
    end

    MailerHelper.env_hash.each_pair do |k, v|
      context 'environments' do
        let(:env_url) { [k, v] }

        it "State the environment #{k.to_s.upcase} in the body" do
          expect(@email.body.to_s.split("\n").first).to match(/.*#{k.to_s.upcase}.*/)
        end
      end
    end
  end
end
