# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionalEmailAnalyticsJob, type: :job do
  subject do
    described_class.new
  end

  before do
    allow(Settings.govdelivery).to receive(:token).and_return('asdf')
    allow(Settings.google_analytics).to receive(:tracking_id).and_return('UA-XXXXXXXXX-1')
  end

  describe '#perform', run_at: '2018-05-30 18:18:56' do
    context 'GovDelivery token is missing from settings' do
      it 'raises an error' do
        allow(FeatureFlipper).to receive(:send_email?).and_return(false)
        expect { subject.perform }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'Google Analytics tracking ID is missing from settings' do
      it 'raises an error' do
        allow(Settings.google_analytics).to receive(:tracking_id).and_return(nil)
        expect { subject.perform }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    it 'retrieves messages at least once, and stop when loop-break conditions are met' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect(subject).to receive(:relevant_emails).twice.and_call_original
        subject.perform
      end
    end

    it 'processes transactional emails for Google Analytics evaluation' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect(subject).to receive(:eval_email).exactly(3).times
        subject.perform
      end
    end

    it 'sends events to Google Analytics' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect_any_instance_of(Staccato::Tracker).to receive(:event).exactly(4).times
        subject.perform
      end
    end
  end

  describe '#we_should_break?', run_at: '2018-05-30 18:27:56' do
    before do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        subject.send(:relevant_emails, 1)
        @emails = subject.instance_variable_get(:@all_emails)
      end
    end

    context 'last email created_at > time-range start time and 50 emails in collection' do
      it 'returns false' do
        @emails.collection.last.attributes[:created_at] = 1440.minutes.ago.to_s
        expect(subject.send(:we_should_break?)).to be false
      end
    end

    context 'last email created_at < time-range start time' do
      it 'returns true' do
        @emails.collection.last.attributes[:created_at] = 25.hours.ago.to_s
        expect(subject.send(:we_should_break?)).to be true
      end
    end

    context 'less than 50 emails were returned by govdelivery' do
      it 'returns true' do
        @emails.collection.delete_at(0)
        expect(subject.send(:we_should_break?)).to be true
      end
    end
  end

  describe '.mailers' do
    it 'returns all the possible TransactionalEmailMailer descendants' do
      # constantize all mailers so they are loaded
      Dir['app/mailers/*.rb']
        .collect { |mailer| %r{app/mailers/(.*)\.rb}.match(mailer)[1] }
        .map { |mailer_name| mailer_name.camelize.constantize }

      expect(TransactionalEmailAnalyticsJob.mailers).to match_array(TransactionalEmailMailer.descendants)
    end
  end
end
