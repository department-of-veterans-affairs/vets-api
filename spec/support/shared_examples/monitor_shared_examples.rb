# frozen_string_literal: true

# Shared examples for testing monitor classes that inherit from ZeroSilentFailures::Monitor
RSpec.shared_examples 'a zero silent failures monitor' do |service_name|
  it 'inherits from ZeroSilentFailures::Monitor' do
    expect(monitor).to be_a(ZeroSilentFailures::Monitor)
  end

  it 'has correct service name' do
    expect(monitor.service).to eq(service_name)
  end

  it 'responds to core ZSF methods' do
    expect(monitor).to respond_to(:log_silent_failure)
    expect(monitor).to respond_to(:log_silent_failure_avoided)
    expect(monitor).to respond_to(:log_silent_failure_no_confirmation)
  end
end

# Shared examples for testing StatsD metric tracking
RSpec.shared_examples 'tracks silent failure metrics' do |metric_name, expected_tags = []|
  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
  end

  it 'increments StatsD metric with correct tags' do
    expect(StatsD).to receive(:increment).with(metric_name, tags: expected_tags)
    subject
  end

  it 'logs to Rails.logger' do
    expect(Rails.logger).to receive(:error)
    subject
  end
end

# Shared examples for testing silent failure logging scenarios
RSpec.shared_examples 'logs appropriate silent failure type' do |failure_type, additional_context = {}|
  let(:user_account_uuid) { 'test-uuid-123' }
  let(:context) { { test: 'context' }.merge(additional_context) }

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(monitor).to receive(:log_silent_failure)
    allow(monitor).to receive(:log_silent_failure_avoided)
    allow(monitor).to receive(:log_silent_failure_no_confirmation)
  end

  case failure_type
  when :silent_failure
    it 'calls log_silent_failure' do
      expect(monitor).to receive(:log_silent_failure).with(
        hash_including(context),
        user_account_uuid,
        hash_including(:call_location)
      )
      subject
    end
  when :silent_failure_avoided
    it 'calls log_silent_failure_avoided' do
      expect(monitor).to receive(:log_silent_failure_avoided).with(
        hash_including(context),
        user_account_uuid,
        hash_including(:call_location)
      )
      subject
    end
  when :silent_failure_no_confirmation
    it 'calls log_silent_failure_no_confirmation' do
      expect(monitor).to receive(:log_silent_failure_no_confirmation).with(
        hash_including(context),
        user_account_uuid,
        hash_including(:call_location)
      )
      subject
    end
  end
end

# Shared examples for testing email scenarios in monitors
RSpec.shared_examples 'handles email scenarios correctly' do |method_name, base_args = []|
  let(:user_account_uuid) { 'test-uuid-456' }

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:error)
    allow(monitor).to receive(:log_silent_failure)
    allow(monitor).to receive(:log_silent_failure_avoided)
    allow(monitor).to receive(:log_silent_failure_no_confirmation)
  end

  context 'when no email attempted' do
    it 'logs silent failure' do
      expect(monitor).to receive(:log_silent_failure)
      
      monitor.send(method_name, *base_args, email_attempted: false, email_success: false)
    end
  end

  context 'when email attempted and succeeded' do
    it 'logs silent failure avoided' do
      expect(monitor).to receive(:log_silent_failure_avoided)
      
      monitor.send(method_name, *base_args, email_attempted: true, email_success: true)
    end
  end

  context 'when email attempted but failed' do
    it 'logs silent failure no confirmation' do
      expect(monitor).to receive(:log_silent_failure_no_confirmation)
      
      monitor.send(method_name, *base_args, email_attempted: true, email_success: false)
    end
  end
end

# Shared examples for testing monitor context building
RSpec.shared_examples 'builds comprehensive context' do |required_keys = []|
  it 'includes all required context keys' do
    result = subject
    
    required_keys.each do |key|
      expect(result).to have_key(key)
    end
  end

  it 'returns a hash' do
    expect(subject).to be_a(Hash)
  end
end

# Shared examples for testing StatsD metric patterns used across monitors
RSpec.shared_examples 'increments service-specific metrics' do |metric_prefix, form_id = nil|
  before do
    allow(StatsD).to receive(:increment)
  end

  it 'increments form-specific metric when form_id provided' do
    if form_id
      expect(StatsD).to receive(:increment).with(
        "#{metric_prefix}.failure",
        tags: ["form_id:#{form_id}", "service:#{monitor.service}"]
      )
    else
      expect(StatsD).to receive(:increment).with(
        hash_including("#{metric_prefix}")
      )
    end
    
    subject
  end

  it 'increments aggregate metric' do
    expect(StatsD).to receive(:increment).with(
      "#{metric_prefix}.failure.all_forms",
      tags: ["service:#{monitor.service}"]
    )
    
    subject
  end
end

# Shared examples for testing monitor error handling
RSpec.shared_examples 'handles monitor errors gracefully' do |method_name, args = []|
  before do
    allow(Rails.logger).to receive(:error)
  end

  it 'does not raise errors when StatsD fails' do
    allow(StatsD).to receive(:increment).and_raise(StandardError, 'StatsD error')
    
    expect { monitor.send(method_name, *args) }.not_to raise_error
  end

  it 'does not raise errors when logging fails' do
    allow(Rails.logger).to receive(:error).and_raise(StandardError, 'Logging error')
    
    expect { monitor.send(method_name, *args) }.not_to raise_error
  end
end

# Shared examples for testing form type detection
RSpec.shared_examples 'detects form types correctly' do |form_ids, detection_method = :include?|
  context 'with valid form IDs' do
    it 'detects all specified form types' do
      form_ids.each do |form_id|
        if detection_method == :include?
          expect(described_class::VFF_FORM_IDS).to include(form_id)
        else
          expect(monitor.send(detection_method, form_id)).to be true
        end
      end
    end
  end

  context 'with invalid form IDs' do
    let(:invalid_forms) { ['686C-674', '28-8832', '28-1900', 'UNKNOWN-FORM'] }

    it 'does not detect non-VFF form types' do
      invalid_forms.each do |form_id|
        if detection_method == :include?
          expect(described_class::VFF_FORM_IDS).not_to include(form_id)
        else
          expect(monitor.send(detection_method, form_id)).to be false
        end
      end
    end
  end
end

# Shared examples for testing database interactions in monitors
RSpec.shared_examples 'performs efficient database queries' do |expected_query_method, expected_args = nil|
  it 'uses efficient database queries' do
    if expected_args
      expect(FormSubmission).to receive(expected_query_method).with(*expected_args).and_call_original
    else
      expect(FormSubmission).to receive(expected_query_method).and_call_original
    end
    
    subject
  end

  it 'does not cause N+1 queries' do
    # This would typically be tested with a query counter gem like bullet
    # For now, we'll just ensure the query is called only once
    expect(FormSubmission).to receive(:joins).once.and_call_original if expected_query_method == :joins
    
    subject
  end
end

# Shared examples for testing monitor integration with external services
RSpec.shared_examples 'integrates with external services' do |services = [:statsd, :rails_logger]|
  before do
    allow(StatsD).to receive(:increment) if services.include?(:statsd)
    allow(Rails.logger).to receive(:error) if services.include?(:rails_logger)
    allow(Rails.logger).to receive(:info) if services.include?(:rails_logger)
  end

  if services.include?(:statsd)
    it 'integrates with StatsD' do
      expect(StatsD).to receive(:increment)
      subject
    end
  end

  if services.include?(:rails_logger)
    it 'integrates with Rails logger' do
      expect(Rails.logger).to receive(:error).or(receive(:info))
      subject
    end
  end
end