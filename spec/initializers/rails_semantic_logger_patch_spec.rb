# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Rails Semantic Logger Patch' do
  describe 'send_data.action_controller unsubscription' do
    it 'does not have any subscribers for send_data.action_controller notifications' do
      # Get all notification subscribers
      subscribers = ActiveSupport::Notifications.notifier.listeners_for('send_data.action_controller')

      # Verify no subscribers are registered
      expect(subscribers).to be_empty,
                             'Expected no subscribers for send_data.action_controller to prevent PII logging'
    end

    it 'prevents rails_semantic_logger from logging send_data events' do
      # Simulate what would happen if a notification was published
      # If there are no subscribers, this should not produce any logs
      logged_events = []

      # Temporarily capture any logs that would be generated
      allow(Rails.logger).to receive(:info) do |msg|
        logged_events << msg if msg.to_s.include?('send_data')
      end

      # Publish a notification that would normally be logged by rails_semantic_logger
      ActiveSupport::Notifications.instrument('send_data.action_controller',
                                              filename: 'John_Doe_SSN_123456789.pdf',
                                              type: 'application/pdf')

      # Verify no send_data events were logged
      expect(logged_events).to be_empty
    end

    context 'demonstrating the PII leak that would occur without this patch' do
      it 'shows that rails_semantic_logger would log PII-containing filenames if subscribed' do
        # This test demonstrates what WOULD happen if we didn't unsubscribe
        # We'll temporarily create a subscriber similar to what rails_semantic_logger does
        logged_data = nil

        # Simulate rails_semantic_logger's subscription behavior
        test_subscriber = ActiveSupport::Notifications.subscribe('send_data.action_controller') do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)
          # This mimics what rails_semantic_logger would log
          logged_data = {
            event_name: event.name,
            filename: event.payload[:filename],
            type: event.payload[:type]
          }
        end

        begin
          # Publish a notification with PII in the filename
          ActiveSupport::Notifications.instrument('send_data.action_controller',
                                                  filename: 'John_Doe_SSN_123456789.pdf',
                                                  type: 'application/pdf')

          # This demonstrates the PII leak - the full filename with SSN would be logged
          expect(logged_data).to eq({
                                      event_name: 'send_data.action_controller',
                                      filename: 'John_Doe_SSN_123456789.pdf', # <-- PII exposed here!
                                      type: 'application/pdf'
                                    })

          # Verify the PII is present in what would have been logged
          expect(logged_data[:filename]).to include('123456789')  # SSN exposed
          expect(logged_data[:filename]).to include('John_Doe')   # Name exposed
        ensure
          # Clean up our test subscriber
          ActiveSupport::Notifications.unsubscribe(test_subscriber)
        end

        # Verify our patch prevents this by ensuring no subscribers remain
        subscribers = ActiveSupport::Notifications.notifier.listeners_for('send_data.action_controller')
        expect(subscribers).to be_empty
      end
    end
  end

  describe 'initialization' do
    it 'has successfully unsubscribed from send_data notifications' do
      # This test verifies the initialization happened by checking
      # that no subscribers exist (which means our patch was applied)
      subscribers = ActiveSupport::Notifications.notifier.listeners_for('send_data.action_controller')
      expect(subscribers).to be_empty
    end

    it 'does not interfere with other action_controller notifications' do
      # Verify other notifications still work
      process_action_subscribers = ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')

      # We expect some subscribers for process_action (rails_semantic_logger subscribes to this)
      expect(process_action_subscribers).not_to be_empty
    end
  end

  describe 'parameter filtering verification' do
    it 'confirms filename is not in the ALLOWLIST' do
      # Verify that 'filename' is not whitelisted in filter parameters
      expect(ALLOWLIST).not_to include('filename')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
