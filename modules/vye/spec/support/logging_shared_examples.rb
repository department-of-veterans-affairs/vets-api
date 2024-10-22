# frozen_string_literal: true

RSpec.shared_examples 'logging behavior' do |messages|
  let(:logger) { Rails.logger }

  it 'writes appropriate messages to the log' do
    # Stub log levels
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)

    # Run the job synchronously, the timing is important here
    described_class.new.perform
    described_class.drain

    messages.each do |message|
      expect(logger.received_message?(message[:log_level], message[:text])).to be(true)
    end
  end
end
