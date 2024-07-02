# frozen_string_literal: true

require 'rails_helper'
require VAForms::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe VAForms::FormReloader, type: :job do
  describe '#perform' do
    subject { described_class }

    let(:slack_messenger) { instance_double(VAForms::Slack::Messenger) }
    let(:form_count) { 1 } # gql_forms.yml cassette only returns one form

    before do
      Sidekiq::Job.clear_all
      allow(Rails.logger).to receive(:error)
      allow(VAForms::Slack::Messenger).to receive(:new).and_return(slack_messenger)
      allow(slack_messenger).to receive(:notify!)
      allow(StatsD).to receive(:increment)
    end

    it 'schedules a child FormBuilder job for each form retrieved' do
      with_settings(Settings.va_forms.form_reloader, enabled: true) do
        VCR.use_cassette('va_forms/forms') do
          described_class.new.perform
          expect(VAForms::FormBuilder.jobs.size).to eq(form_count)
        end
      end
    end

    context 'when the forms server returns an error' do
      it 'raises an error and does not schedule any child FormBuilder jobs' do
        with_settings(Settings.va_forms.form_reloader, enabled: true) do
          VCR.use_cassette('va_forms/forms_500_error') do
            expect { described_class.new.perform }.to raise_error(NoMethodError)
            expect(VAForms::FormBuilder.jobs.size).to eq(0)
          end
        end
      end
    end

    context 'when the job is disabled in settings' do
      it 'does not schedule any child FormBuilder jobs' do
        with_settings(Settings.va_forms.form_reloader, enabled: false) do
          VCR.use_cassette('va_forms/forms_500_error') do
            expect(VAForms::FormBuilder.jobs.size).to eq(0)
          end
        end
      end
    end

    context 'when all retries have been exhausted' do
      let(:error) { RuntimeError.new('an error occurred!') }
      let(:msg) do
        {
          'jid' => 123,
          'class' => described_class.to_s,
          'error_class' => 'RuntimeError',
          'error_message' => 'an error occurred!'
        }
      end

      it 'increments the StatsD counter' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(StatsD).to(receive(:increment))
                        .with("#{described_class::STATSD_KEY_PREFIX}.exhausted")
                        .exactly(1).time
        end
      end

      it 'logs an error to the Rails console' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(Rails.logger).to receive(:error).with(
            'VAForms::FormReloader retries exhausted',
            {
              job_id: 123,
              error_class: 'RuntimeError',
              error_message: 'an error occurred!'
            }
          )
        end
      end

      it 'notifies Slack' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(VAForms::Slack::Messenger).to receive(:new).with(
            {
              class: 'VAForms::FormReloader',
              exception: 'RuntimeError',
              exception_message: 'an error occurred!',
              detail: 'VAForms::FormReloader retries exhausted'
            }
          ).and_return(slack_messenger)
          expect(slack_messenger).to receive(:notify!)
        end
      end
    end
  end
end
