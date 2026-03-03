# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Preneeds::BurialForm', type: :request do
  include SchemaMatchers

  let(:params) do
    { application: attributes_for(:burial_form) }
  end

  # /v0/preneeds/burial_forms specs already removed in https://github.com/department-of-veterans-affairs/vets-api/pull/18232

  describe '#send_confirmation_email' do
    subject { V0::Preneeds::BurialFormsController.new }

    let(:submission_record) { OpenStruct.new(application_uuid: 'UUID') }
    let(:form) do
      Preneeds::BurialForm.new(params[:application]).tap do |f|
        f.claimant = Preneeds::Claimant.new(
          email: 'foo@foo.com',
          name: Preneeds::FullName.new(
            first: 'Derrick',
            last: 'Last'
          )
        )
        f.applicant = Preneeds::Applicant.new(
          applicant_relationship_to_claimant: 'Self',
          applicant_email: 'bar@bar.com',
          name: Preneeds::FullName.new(
            first: 'Applicant',
            last: 'Last'
          )
        )
      end
    end

    context 'when va_notify_v2_preneeds_burial_form_job is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_v2_preneeds_burial_form_job).and_return(false)
      end

      it 'calls VANotify::EmailJob with the correct parameters' do
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          'foo@foo.com',
          'preneeds_burial_form_email_template_id',
          {
            'form_name' => 'Burial Pre-Need (Form 40-10007)',
            'applicant_1_first_name_last_initial' => 'Applicant L',
            'confirmation_number' => 'UUID',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'first_name' => 'APPLICANT'
          }
        )
        expect(VANotify::V2::QueueEmailJob).not_to receive(:enqueue)

        subject.instance_variable_set(:@form, form)
        subject.instance_variable_set(:@resource, submission_record)
        subject.send_confirmation_email
      end
    end

    context 'when va_notify_v2_preneeds_burial_form_job is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:va_notify_v2_preneeds_burial_form_job).and_return(true)
      end

      it 'calls VANotify::V2::QueueEmailJob.enqueue with the correct parameters' do
        expect(VANotify::V2::QueueEmailJob).to receive(:enqueue).with(
          'foo@foo.com',
          'preneeds_burial_form_email_template_id',
          {
            'form_name' => 'Burial Pre-Need (Form 40-10007)',
            'applicant_1_first_name_last_initial' => 'Applicant L',
            'confirmation_number' => 'UUID',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'first_name' => 'APPLICANT'
          },
          'Settings.vanotify.services.va_gov.api_key'
        )
        expect(VANotify::EmailJob).not_to receive(:perform_async)

        subject.instance_variable_set(:@form, form)
        subject.instance_variable_set(:@resource, submission_record)
        subject.send_confirmation_email
      end
    end
  end
end
