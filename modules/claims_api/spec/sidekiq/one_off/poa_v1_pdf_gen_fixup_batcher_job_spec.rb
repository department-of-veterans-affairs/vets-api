# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::OneOff::PoaV1PdfGenFixupBatcherJob, type: :job do
  subject { described_class.new }

  let(:log_tag) { described_class::LOG_TAG }

  it 'enqueues the PoaV1PdfGenFixupJobs at the right intervals' do
    Timecop.freeze(Date.parse('2025-01-01').beginning_of_day) do
      expect(ClaimsApi::OneOff::PoaV1PdfGenFixupJob).to receive(:perform_in).exactly(2077).times
      allow(ClaimsApi::Logger).to receive(:log)
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag,
                                                      detail: 'Found 2077 IDs in CSV file')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag,
                                                      detail: 'Successfully enqueued 2077 PoaV1PdfGenFixupJob jobs')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag,
                                                      detail: 'Estimated completion time: 2025-01-01 03:27:42 UTC')
      subject.perform
    end
  end

  it 'handles empty CSV file' do
    allow(CSV).to receive(:read).and_return([])
    expect(ClaimsApi::Logger).to receive(:log).with(log_tag, level: :error, detail: 'No IDs found in CSV file')
    expect_any_instance_of(SlackNotify::Client).to receive(:notify)
    subject.perform
  end

  it 'Logs details & re-raises when an exception is thrown partway through' do
    Timecop.freeze(Date.parse('2025-01-01').beginning_of_day) do
      error = StandardError.new('Some error')

      call_count = 0
      allow(ClaimsApi::OneOff::PoaV1PdfGenFixupJob).to receive(:perform_in) do
        call_count += 1
        raise error if call_count == 51 # Fails on the 51st call, so 50 calls succeeded
      end

      expect(ClaimsApi::Logger).to receive(:log).with(log_tag,
                                                      detail: 'Found 2077 IDs in CSV file')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, detail: 'Exception thrown',
                                                               level: :error,
                                                               error_class: error.class.name,
                                                               error: 'Some error')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag, level: :error,
                                                               detail: 'Was able to enqueue 50 jobs')
      expect(ClaimsApi::Logger).to receive(:log).with(log_tag,
                                                      level: :error,
                                                      detail: 'Estimated completion time: 2025-01-01 00:05:00 UTC')
      expect_any_instance_of(SlackNotify::Client).to receive(:notify)

      expect { subject.perform }.to raise_error(error)
    end
  end
end
