# frozen_string_literal: true

shared_examples 'a monitored worker' do |_options|
  it 'defines #notify' do
    expect(described_class.new.respond_to?(:notify)).to be(true)
  end

  it 'requires a parameter for notify' do
    expect { described_class.new.notify }
      .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
  end

  it 'defines retry_limits_for_notification' do
    expect(described_class.new.respond_to?(:retry_limits_for_notification)).to be(true)
  end

  it 'returns an array of integers from retry_limits_for_notification' do
    expect(described_class.new.retry_limits_for_notification).to be_a(Array)
  end

  it 'calls SidekiqRetryNotifer' do
    messager_instance = instance_double(AppealsApi::Slack::Messager)
    allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
    allow(messager_instance).to receive(:notify!)
    described_class.new.notify({})
    expect(messager_instance).to have_received(:notify!)
  end
end
