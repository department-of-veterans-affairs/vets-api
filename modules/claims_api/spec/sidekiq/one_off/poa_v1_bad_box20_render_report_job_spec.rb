# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::OneOff::PoaV1BadBox20RenderReportJob, type: :job do
  subject { described_class.new }

  let(:log_tag) { described_class::LOG_TAG }
  let(:consumer_id) { Faker::Alphanumeric.alphanumeric(number: 10) }

  describe '#perform' do
    before do
      Timecop.freeze('Jan 10, 2025') do
        # Skipped by job - consent limitation(s) chosen
        create_list(:power_of_attorney, 2, :with_fuzzed_headers, :with_consent_limit, cid: consumer_id)
        # Reported by job - Has no consent limit fields in form_data, thus no chosen consent limitation(s)
        create_list(:power_of_attorney, 3, cid: consumer_id)
        # Reported by job - consentLimit field provided, but no chosen limitation(s)
        create_list(:power_of_attorney, 4, :with_fuzzed_headers, :with_blank_consent_limit, cid: consumer_id)
      end
      # Jump by 2 weeks to ensure job can handle weeks w/ no applicable records
      Timecop.freeze('Jan 24, 2025') do
        # Reported by job - consentLimit field provided, but no chosen limitation(s)
        create_list(:power_of_attorney, 5, :with_fuzzed_headers, :with_blank_consent_limit, cid: consumer_id)
      end
      # Skipped by job - Would apply, but falls outside date range of bugged PDF generation
      create_list(:power_of_attorney, 6, :with_fuzzed_headers, :with_blank_consent_limit, cid: consumer_id)
    end

    it 'logs progress and sends emails' do
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Started processing')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Found 7 record(s)') # 3 + 4 week 1
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Sending email for week of 2025-01-07')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Email sent')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'No records for week of 2025-01-13')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Found 5 record(s)') # 5 week 3
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Sending email for week of 2025-01-20')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Email sent')

      allow(ClaimsApi::OneOff::PoaV1BadBox20RenderReportMailer).to receive(:build).and_return(
        double.tap do |mailer|
          expect(mailer).to receive(:deliver_now).twice
        end
      )

      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Job complete')
      subject.perform(consumer_id, %w[example@va.gov], '2025-01-07', '2025-01-26')
    end

    context 'Non-retrying failures' do
      it 'Alerts when Consumer ID is blank' do
        expect(ClaimsApi::Logger).to receive(:log).once
        expect_any_instance_of(SlackNotify::Client).to receive(:notify)
        subject.perform('', %w[example@va.gov])
      end

      it 'Alerts when no emails are provided' do
        expect(ClaimsApi::Logger).to receive(:log).once
        expect_any_instance_of(SlackNotify::Client).to receive(:notify).once
        subject.perform(consumer_id, %w[])
      end

      it 'Alerts when non-VA email is provided' do
        expect(ClaimsApi::Logger).to receive(:log).once
        expect_any_instance_of(SlackNotify::Client).to receive(:notify).once
        subject.perform(consumer_id, %w[valid@va.gov invalid@example.com])
      end
    end

    context 'Exception thrown' do
      it 'Alerts & re-raises the exception class' do
        error = StandardError.new('Some error')
        allow_any_instance_of(ApplicationMailer).to receive(:mail).and_raise(error)
        expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Started processing')
        expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Found 7 record(s)')
        expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Sending email for week of 2025-01-07')
        expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Exception thrown',
                                                                 level: :error,
                                                                 error: error.class.name)
        expect_any_instance_of(SlackNotify::Client).to receive(:notify).once
        expect do
          subject.perform consumer_id, %w[example@va.gov]
        end.to raise_error(error)
      end
    end
  end
end
