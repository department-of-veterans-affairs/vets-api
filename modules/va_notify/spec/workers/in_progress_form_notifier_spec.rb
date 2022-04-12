# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'
Sidekiq::Testing.fake!

describe VANotify::InProgressFormNotifier, type: :worker do
  let(:template_id) { 'template_id' }
  let(:user) { create(:user) }
  let(:in_progress_form) { create(:in_progress_686c_form, user_uuid: user.uuid) }
  let(:notification_client) { double('VaNotify::Service') }

  before do
    allow_any_instance_of(VaNotify::Configuration).to receive(:base_path).and_return('http://fakeapi.com')

    allow(Settings.vanotify.services.va_gov).to receive(:api_key).and_return(
      'test-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
    )
  end

  describe '#perform' do
    it 'fails if ICN is not present' do
      client = double
      allow(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)
      user_without_icn = double('VANotify::Veteran')
      allow(VANotify::Veteran).to receive(:new).and_return(user_without_icn)
      allow(user_without_icn).to receive(:mpi_icn).and_return(nil)

      expect do
        described_class.new.perform(in_progress_form.id)
      end.to raise_error(VANotify::InProgressFormNotifier::MissingICN,
                         "ICN not found for InProgressForm: #{in_progress_form.id}")
    end

    it 'fails if it can not parse InProgressForm data (unrecognized form_id)' do
      allow(VaNotify::Service).to receive(:new).and_return(notification_client)

      invalid_form = create(:in_progress_form, form_id: 'invalid_id')

      expect do
        subject.perform(invalid_form.id)
      end.to raise_error(VANotify::InProgressFormNotifier::UnsupportedForm,
                         "Unsupported form: #{invalid_form.form_id} - InProgressForm: #{invalid_form.id}")
    end

    it 'sends an email (with ICN data) using the template id' do
      client = double
      allow(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

      expect(client).to receive(:send_email).with(
        recipient_identifier: { id_type: 'ICN', id_value: '1013062086V794840' },
        template_id: 'fake_template_id',
        personalisation: {
          'first_name' => 'First_name',
          'date' => in_progress_form.expires_at.strftime('%B %d, %Y')
        }
      )

      described_class.new.perform(in_progress_form.id)
    end

    it 'handles 4xx errors when sending an email' do
      allow(VaNotify::Service).to receive(:new).and_return(notification_client)

      error = Common::Exceptions::BackendServiceException.new(
        'VANOTIFY_400',
        { source: VaNotify::Service.to_s },
        400,
        'Error'
      )
      allow(notification_client).to receive(:send_email).and_raise(error)

      expect(subject).to receive(:log_exception_to_sentry).with(error) # rubocop:disable RSpec/SubjectStub
      expect { subject.perform(in_progress_form.id) }
        .to raise_error(Common::Exceptions::BackendServiceException)
        .and trigger_statsd_increment('worker.in_progress_form_email.error')
    end

    it 'handles 5xx errors when sending an email' do
      allow(VaNotify::Service).to receive(:new).and_return(notification_client)

      error = Common::Exceptions::BackendServiceException.new(
        'VANOTIFY_500',
        { source: VaNotify::Service.to_s },
        500,
        'Error'
      )
      allow(notification_client).to receive(:send_email).and_raise(error)

      expect(subject).to receive(:log_exception_to_sentry).with(error) # rubocop:disable RSpec/SubjectStub
      expect { subject.perform(in_progress_form.id) }
        .to raise_error(Common::Exceptions::BackendServiceException)
        .and trigger_statsd_increment('worker.in_progress_form_email.error')
    end
  end
end
