# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionalEmailAnalyticsJob, type: :job do
  subject do
    described_class.new
  end

  before do
    Settings.govdelivery.token = 'asdf'
    Settings.google_analytics_tracking_id = 'UA-XXXXXXXXX-1'
  end

  describe 'ensure all subclasses are properly configured' do
    EmailStruct = Struct.new(:subject, :status, :created_at, :id) do
      def initialize(subject, status = 'completed', created_at = 24.hours.ago.to_s, id = rand(50_000_000..99_999_999))
        super
      end

      def failed
        Struct.new(:get, :collection).new(false, [])
      end
    end

    it 'works' do
      client = double('GovDelivery::TMS::Client')
      email_messages = double('GovDelivery::TMS::EmailMessages')
      allow(email_messages).to receive(:collection) {
        emails = described_class::TRANSACTIONAL_MAILERS.each_with_object([]) do |mailer, arr|
          arr << EmailStruct.new(mailer::SUBJECT)
          arr << EmailStruct.new(mailer::SUBJECT, 'sending')
        end
        emails << EmailStruct.new('Spool submissions report')
      }
      allow(client).to receive_message_chain(:email_messages, :get).and_return(email_messages)
      expect(subject).to receive(:govdelivery_client).and_return(client)
      expect(subject).to receive(:relevant_emails).at_least(:once).and_call_original
      expect_any_instance_of(Staccato::Tracker).to receive(:event).twice
      subject.perform
    end
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
        Settings.google_analytics_tracking_id = nil
        expect { subject.perform }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    it 'should retrieve messages at least once, and stop when loop-break conditions are met' do
      VCR.use_cassette('govdelivery_emails', allow_playback_repeats: true) do
        expect(subject).to receive(:relevant_emails).twice.and_call_original
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
        subject.send(:relevant_emails, 1)
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
