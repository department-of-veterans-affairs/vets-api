# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper::Instrumentation::EventSubscriber do
  let(:subscriber) { described_class.new }
  let(:feature_name) { 'test_feature' }
  let(:user_email) { 'user@example.com' }

  before do
    # Clear RequestStore before each test
    RequestStore.store[:flipper_user_email_for_log] = nil
  end

  describe '#call' do
    let(:event_name) { 'feature_operation.flipper' }
    let(:started) { Time.current }
    let(:finished) { Time.current + 1.second }
    let(:unique_id) { SecureRandom.hex(10) }

    context 'when operation is enable' do
      let(:payload) do
        {
          operation: :enable,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'creates a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :enable,
          gate_name: :boolean,
          value: true,
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is disable' do
      let(:payload) do
        {
          operation: :disable,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: false)
        }
      end

      it 'creates a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :disable,
          gate_name: :boolean,
          value: false,
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is add' do
      let(:payload) do
        {
          operation: :add,
          feature_name: feature_name,
          gate_name: :actors,
          thing: double(value: 'User:123')
        }
      end

      it 'creates a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :add,
          gate_name: :actors,
          value: 'User:123',
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is remove' do
      let(:payload) do
        {
          operation: :remove,
          feature_name: feature_name,
          gate_name: :actors,
          thing: double(value: 'User:456')
        }
      end

      it 'creates a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :remove,
          gate_name: :actors,
          value: 'User:456',
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is clear' do
      let(:payload) do
        {
          operation: :clear,
          feature_name: feature_name,
          gate_name: :percentage_of_actors,
          thing: double(value: 0)
        }
      end

      it 'creates a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :clear,
          gate_name: :percentage_of_actors,
          value: 0,
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when thing is nil' do
      let(:payload) do
        {
          operation: :enable,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: nil
        }
      end

      it 'creates a FeatureToggleEvent with nil value' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :enable,
          gate_name: :boolean,
          value: nil,
          user: user_email
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when user is not set in RequestStore' do
      let(:payload) do
        {
          operation: :enable,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'creates a FeatureToggleEvent with nil user' do
        expect(FeatureToggleEvent).to receive(:create).with(
          feature_name: feature_name,
          operation: :enable,
          gate_name: :boolean,
          value: true,
          user: nil
        )

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is enabled? (read operation)' do
      let(:payload) do
        {
          operation: :enabled?,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'does not create a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).not_to receive(:create)

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is exist? (read operation)' do
      let(:payload) do
        {
          operation: :exist?,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'does not create a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).not_to receive(:create)

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is state (read operation)' do
      let(:payload) do
        {
          operation: :state,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'does not create a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).not_to receive(:create)

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is on (read operation)' do
      let(:payload) do
        {
          operation: :on,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: true)
        }
      end

      it 'does not create a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).not_to receive(:create)

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end

    context 'when operation is off (read operation)' do
      let(:payload) do
        {
          operation: :off,
          feature_name: feature_name,
          gate_name: :boolean,
          thing: double(value: false)
        }
      end

      it 'does not create a FeatureToggleEvent' do
        RequestStore.store[:flipper_user_email_for_log] = user_email

        expect(FeatureToggleEvent).not_to receive(:create)

        subscriber.call(event_name, started, finished, unique_id, payload)
      end
    end
  end

  describe 'subscription' do
    it 'subscribes to feature_operation.flipper notifications' do
      # Verify that the subscription is set up
      expect(ActiveSupport::Notifications).to receive(:subscribe).with(
        /feature_operation.flipper/,
        instance_of(described_class)
      )

      load 'lib/flipper/instrumentation/event_subscriber.rb'
    end
  end

  describe 'integration test' do
    it 'responds to ActiveSupport::Notifications events' do
      RequestStore.store[:flipper_user_email_for_log] = user_email

      expect(FeatureToggleEvent).to receive(:create).with(
        feature_name: feature_name,
        operation: :enable,
        gate_name: :boolean,
        value: true,
        user: user_email
      )

      ActiveSupport::Notifications.instrument(
        'feature_operation.flipper',
        operation: :enable,
        feature_name: feature_name,
        gate_name: :boolean,
        thing: double(value: true)
      )
    end
  end
end
