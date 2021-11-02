# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::UnsuccessfulReportMailer, type: [:mailer] do
  let(:error_upload) { FactoryBot.create(:upload_submission, :status_error) }
  let(:uploaded_upload) { FactoryBot.create(:upload_submission, :status_uploaded) }
  let(:totals) do
    { 'vetraspec' => {
      'error' => 1,
      'expired' => 2,
      'processing' => 4,
      'received' => 1,
      'success' => 1,
      'uploaded' => 1,
      'vbms' => 1,
      :totals => 11,
      :success_rate => '18%',
      :error_rate => '9%',
      :expired_rate => '18%'
    },
      'vetpro' => {
        'expired' => 1,
        'success' => 1,
        'vbms' => 1,
        :totals => 3,
        :success_rate => '67%',
        :error_rate => '0%',
        :expired_rate => '33%'
      },
      'summary' => {
        'pending' => 0,
        'uploaded' => 1,
        'received' => 1,
        'processing' => 4,
        'success' => 2,
        'vbms' => 2,
        'error' => 1,
        'expired' => 6,
        'total' => 17,
        'success_rate' => '24%',
        'error_rate' => '6%',
        'expired_rate' => '35%'
      } }
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
      }.freeze
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

        it "sends to the right people for #{k}" do
          people = VBADocuments::UnsuccessfulReportMailer.fetch_recipients
          expect(@email.to).to eq(people)
        end

        it "states the environment #{k.to_s.upcase} in the body" do
          @email.body.to_s =~ %r{<h1>(.*)?</h1>}i
          expect(Regexp.last_match(1)).to match(/.*#{k.to_s.upcase}.*/)
        end
      end
    end
  end
end
