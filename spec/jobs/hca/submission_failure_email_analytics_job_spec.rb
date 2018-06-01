# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::SubmissionFailureEmailAnalyticsJob, type: :job do
  subject do
    described_class.new
  end

  before do
    Settings.reports.token = 'asdf'
    Settings.reports.server = 'stage-tms.govdelivery.com'
    Settings.google_analytics.tracking_id = 'UA-XXXXXXXXX-1'
  end

  describe '#perform', run_at: '2018-05-30 18:18:56' do
    context 'GovDelivery token is missing from settings' do
      it 'should raise an error' do
        allow(FeatureFlipper).to receive(:send_email?).and_return(false)
        expect { subject.perform }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'Google Analytics tracking ID is missing from settings' do
      it 'should raise an error' do
        Settings.google_analytics.tracking_id = nil
        expect { subject.perform }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    it 'should retrieve messages at least once, and stop when loop-break conditions are met' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect(subject).to receive(:hca_emails).twice.and_call_original
        subject.perform
      end
    end

    it 'should process HCA failure emails for Google Analytics evaluation' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect(subject).to receive(:eval_email).twice
        subject.perform
      end
    end

    it 'should send events to Google Analytics' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect_any_instance_of(Staccato::Tracker).to receive(:event).exactly(3).times
        subject.perform
      end
    end
  end

  describe '#we_should_break?', run_at: '2018-05-30 18:27:56' do
    before do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        subject.send(:hca_emails, 1)
        @emails = subject.instance_variable_get(:@all_emails)
      end
    end
    context 'last email created_at > time-range start time and 50 emails in collection' do
      it 'should return false' do
        @emails.collection.last.attributes[:created_at] = 1440.minutes.ago.to_s
        expect(subject.send(:we_should_break?)).to be false
      end
    end
    context 'last email created_at < time-range start time' do
      it 'should return true' do
        @emails.collection.last.attributes[:created_at] = 25.hours.ago.to_s
        expect(subject.send(:we_should_break?)).to be true
      end
    end
    context 'less than 50 emails were returned by govdelivery' do
      it 'should return true' do
        @emails.collection.delete_at(0)
        expect(subject.send(:we_should_break?)).to be true
      end
    end
  end
end
