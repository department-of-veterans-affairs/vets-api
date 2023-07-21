# frozen_string_literal: true

require 'rails_helper'

require 'debt_management_center/vbs/request'
require 'debt_management_center/workers/va_notify_email_job'

RSpec.describe Form5655::VHAResubmissionJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:form_submission) { create(:form5655_submission) }

    before do
      response = Faraday::Response.new(status: 200, body:
      {
        message: 'Success'
      })
      allow_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post).and_return(response)
    end

    it 'submits to the VBS endpoint' do
      job = described_class.new
      form = form_submission.form
      form['transactionId'] = form_submission.id
      form['timestamp'] = form_submission.created_at.strftime('%Y%m%dT%H%M%S')
      expect_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post).with(
        '/vbsapi/UploadFSRJsonDocument', { jsonDocument: form.to_json }
      )
      job.perform(form_submission.id)
    end

    it 'creates new notification for successful submission' do
      job = described_class.new
      email = form_submission.form['personalData']['emailAddress']
      email_personalization_info = {
        'name' => form_submission.form['personalData']['veteranFullName']['first'],
        'time' => '48 hours',
        'date' => Time.zone.now.strftime('%m/%d/%Y')
      }
      expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
        email,
        described_class::EMAIL_TEMPLATE,
        email_personalization_info
      )
      job.perform(form_submission.id)
    end

    context 'VBS submission fails' do
      before do
        response = Faraday::Response.new(status: 500, body:
      {
        message: 'Something went wrong'
      })
        allow_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post).and_return(response)
      end

      it 'does not send a confirmation email' do
        job = described_class.new
        email = form_submission.form['personalData']['emailAddress']
        email_personalization_info = {
          'name' => form_submission.form['personalData']['veteranFullName']['first'],
          'time' => '48 hours',
          'date' => Time.zone.now.strftime('%m/%d/%Y')
        }
        expect(DebtManagementCenter::VANotifyEmailJob).not_to receive(:perform_async).with(
          email,
          described_class::EMAIL_TEMPLATE,
          email_personalization_info
        )
        job.perform(form_submission.id)
      end
    end
  end
end
