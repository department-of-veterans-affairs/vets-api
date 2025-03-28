# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe 'simple_forms_api:send_emails_by_date_range', type: :task do
  load File.expand_path('../../lib/tasks/send_emails_by_date_range.rake', __dir__)

  let(:task) { Rake::Task['simple_forms_api:send_emails_by_date_range'] }
  let(:notification_email) { double(send: nil) }

  before do
    Rake::Task.define_task(:environment)
  end

  after { task.reenable }

  context 'when valid dates are provided' do
    let(:start_date) { '1 January 2025' }
    let(:end_date) { '3 January 2025' }

    context 'FormSubmissionAttempts are a Simple Form, in an end-state and updated in the right time period' do
      before do
        create(:form_submission_attempt, :vbms, updated_at: Time.zone.parse('2 January 2025'))
        create(:form_submission_attempt, :failure, updated_at: Time.zone.parse('2 January 2025'))
      end

      it 'sends Notification::Emails' do
        expect(SimpleFormsApi::Notification::Email).to receive(:new).with(
          anything,
          notification_type: :received,
          user_account: anything
        ).once.and_return(notification_email)
        expect(SimpleFormsApi::Notification::Email).to receive(:new).with(
          anything,
          notification_type: :error,
          user_account: anything
        ).once.and_return(notification_email)

        task.invoke(start_date, end_date)
      end
    end

    context 'FormSubmissionAttempts are not a Simple Form' do
      let(:form_submission) { build(:form_submission, form_type: 'something-else') }

      before do
        create(:form_submission_attempt, :vbms, form_submission:, updated_at: Time.zone.parse('2 January 2025'))
        create(:form_submission_attempt, :failure, form_submission:, updated_at: Time.zone.parse('2 January 2025'))
      end

      it 'does not send a Notification::Email' do
        expect(SimpleFormsApi::Notification::Email).not_to receive(:new)

        task.invoke(start_date, end_date)
      end
    end

    context 'FormSubmissionAttempts are in an end-state but not updated in the right time period' do
      before do
        create(:form_submission_attempt, :vbms, updated_at: Time.zone.parse('5 January 2025'))
        create(:form_submission_attempt, :failure, updated_at: Time.zone.parse('5 January 2025'))
      end

      it 'does not send Notification::Emails' do
        expect(SimpleFormsApi::Notification::Email).not_to receive(:new)

        task.invoke(start_date, end_date)
      end
    end

    context 'FormSubmissionAttempts are not in an end-state but were updated in the right time period' do
      before do
        create(:form_submission_attempt, :pending, updated_at: Time.zone.parse('2 January 2025'))
      end

      it 'does not send Notification::Emails' do
        expect(SimpleFormsApi::Notification::Email).not_to receive(:new)

        task.invoke(start_date, end_date)
      end
    end
  end
end
