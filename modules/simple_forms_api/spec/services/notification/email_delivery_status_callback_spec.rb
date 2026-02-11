# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe SimpleFormsApi::Notification::EmailDeliveryStatusCallback do
  subject { described_class.new }

  let(:notification_id) { SecureRandom.uuid }
  let(:confirmation_number) { 'abc-123-xyz' }
  let(:form_number) { 'vba_21_4142' }

  let(:event) do
    OpenStruct.new(
      notification_id:,
      template_id: 'template-123',
      to: 'veteran@example.com',
      status: 'delivered',
      sent_at: Time.zone.parse('2025-01-15 10:00:00'),
      completed_at: Time.zone.parse('2025-01-15 10:01:23'),
      notification_type: 'email',
      status_reason: nil,
      callback_metadata: {
        'confirmation_number' => confirmation_number,
        'form_number' => form_number,
        'notification_type' => 'confirmation'
      }
    )
  end

  describe '#call' do
    context 'when creating a new notification record' do
      it 'persists the notification to VANotify::Notification' do
        expect { subject.call(event) }.to change(VANotify::Notification, :count).by(1)

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification).to be_present
        expect(notification.status).to eq('delivered')
        expect(notification.to).to eq('veteran@example.com')
      end

      it 'stores callback_metadata including confirmation_number' do
        subject.call(event)

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification.callback_metadata['confirmation_number']).to eq(confirmation_number)
        expect(notification.callback_metadata['form_number']).to eq(form_number)
      end

      it 'stores all available fields from event' do
        subject.call(event)

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification.notification_id).to eq(notification_id)
        expect(notification.status).to eq('delivered')
        expect(notification.sent_at).to be_within(1.second).of(event.sent_at)
        expect(notification.completed_at).to be_within(1.second).of(event.completed_at)
      end
    end

    context 'when updating an existing notification record' do
      let!(:existing_notification) do
        VANotify::Notification.create!(
          notification_id:,
          status: 'sending',
          to: 'veteran@example.com',
          callback_metadata: {
            'confirmation_number' => confirmation_number,
            'form_number' => form_number
          }
        )
      end

      it 'updates the existing record without creating a duplicate' do
        expect { subject.call(event) }.not_to(change(VANotify::Notification, :count))

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification.status).to eq('delivered')
        expect(notification.completed_at).to be_present
      end

      it 'is idempotent when called multiple times' do
        subject.call(event)
        subject.call(event)
        subject.call(event)

        expect(VANotify::Notification.where(notification_id:).count).to eq(1)
      end
    end

    context 'when event contains failure information' do
      let(:failed_event) do
        OpenStruct.new(
          notification_id:,
          template_id: 'template-123',
          to: 'invalid@example.com',
          status: 'permanent-failure',
          sent_at: Time.zone.parse('2025-01-15 10:00:00'),
          completed_at: Time.zone.parse('2025-01-15 10:00:30'),
          notification_type: 'email',
          status_reason: 'Email address does not exist',
          callback_metadata: {
            'confirmation_number' => confirmation_number,
            'form_number' => form_number
          }
        )
      end

      it 'stores the failure status and reason' do
        subject.call(failed_event)

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification.status).to eq('permanent-failure')
        expect(notification.status_reason).to eq('Email address does not exist')
      end
    end

    context 'when event has minimal fields' do
      let(:minimal_event) do
        OpenStruct.new(
          notification_id:,
          template_id: 'template-123',
          to: 'veteran@example.com',
          status: 'sending',
          callback_metadata: {
            'confirmation_number' => confirmation_number,
            'form_number' => form_number
          }
        )
      end

      it 'handles missing optional fields gracefully' do
        expect { subject.call(minimal_event) }.not_to raise_error

        notification = VANotify::Notification.find_by(notification_id:)
        expect(notification).to be_present
        expect(notification.status).to eq('sending')
      end
    end

    context 'error handling' do
      let(:invalid_event) do
        OpenStruct.new(
          notification_id: nil, # Invalid: null notification_id
          status: 'delivered'
        )
      end

      it 'logs errors and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'SimpleForms EmailDeliveryStatusCallback failure',
          hash_including(:error_class, :error_message)
        )

        expect { subject.call(invalid_event) }.to raise_error(StandardError)
      end
    end
  end

  describe 'querying notifications by confirmation_number' do
    let!(:notification1) do
      VANotify::Notification.create!(
        notification_id: SecureRandom.uuid,
        status: 'delivered',
        to: 'veteran1@example.com',
        callback_metadata: {
          'confirmation_number' => 'uuid-111',
          'form_number' => 'vba_21_4142'
        }
      )
    end

    let!(:notification2) do
      VANotify::Notification.create!(
        notification_id: SecureRandom.uuid,
        status: 'delivered',
        to: 'veteran2@example.com',
        callback_metadata: {
          'confirmation_number' => 'uuid-222',
          'form_number' => 'vba_21_4142'
        }
      )
    end

    let!(:notification3) do
      VANotify::Notification.create!(
        notification_id: SecureRandom.uuid,
        status: 'delivered',
        to: 'veteran3@example.com',
        callback_metadata: {
          'confirmation_number' => 'uuid-333',
          'form_number' => 'vba_21_0966'
        }
      )
    end

    it 'can query notification_ids by multiple confirmation_numbers' do
      results = VANotify::Notification.where(
        "callback_metadata->>'confirmation_number' IN (?)",
        %w[uuid-111 uuid-222 uuid-333]
      ).pluck(:notification_id)

      expect(results).to contain_exactly(
        notification1.notification_id,
        notification2.notification_id,
        notification3.notification_id
      )
    end

    it 'can query by single confirmation_number' do
      result = VANotify::Notification.find_by(
        "callback_metadata->>'confirmation_number' = ?",
        'uuid-111'
      )

      expect(result.notification_id).to eq(notification1.notification_id)
    end

    it 'can filter by confirmation_number and form_number together' do
      results = VANotify::Notification.where(
        "callback_metadata->>'confirmation_number' IN (?) AND callback_metadata->>'form_number' = ?",
        %w[uuid-111 uuid-333],
        'vba_21_4142'
      )

      expect(results.pluck(:notification_id)).to contain_exactly(notification1.notification_id)
    end

    it 'returns empty array when no matches found' do
      results = VANotify::Notification.where(
        "callback_metadata->>'confirmation_number' = ?",
        'nonexistent-uuid'
      )

      expect(results).to be_empty
    end
  end

  describe 'tracking different notification types' do
    %w[confirmation error received].each do |notification_type|
      context "with #{notification_type} notification" do
        let(:event) do
          OpenStruct.new(
            notification_id: SecureRandom.uuid,
            template_id: "template-#{notification_type}",
            to: 'veteran@example.com',
            status: 'delivered',
            callback_metadata: {
              'confirmation_number' => confirmation_number,
              'form_number' => form_number,
              'notification_type' => notification_type
            }
          )
        end

        it "stores #{notification_type} type in callback_metadata" do
          subject.call(event)

          notification = VANotify::Notification.find_by(notification_id: event.notification_id)
          expect(notification.callback_metadata['notification_type']).to eq(notification_type)
        end
      end
    end
  end
end
