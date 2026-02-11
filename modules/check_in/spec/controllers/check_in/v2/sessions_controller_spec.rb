# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::SessionsController, type: :controller do
  routes { CheckIn::Engine.routes }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { instance_double(CheckIn::V2::Session, uuid:) }
  let(:low_auth_token) { 'low-auth-token' }

  before do
    allow(controller).to receive(:low_auth_token).and_return(low_auth_token)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_enabled').and_return(true)
  end

  describe '#pre_checkin?' do
    context 'when checkInType param is preCheckIn' do
      it 'returns true for GET request' do
        get :show, params: { id: uuid, checkInType: 'preCheckIn' }
        expect(controller.send(:pre_checkin?)).to be true
      end
    end

    context 'when session check_in_type is preCheckIn' do
      it 'returns true for POST request' do
        post :create, params: { session: { uuid:, dob: '1970-01-01', last_name: 'Doe', check_in_type: 'preCheckIn' } }
        expect(controller.send(:pre_checkin?)).to be true
      end
    end

    context 'when neither param is preCheckIn' do
      it 'returns false' do
        get :show, params: { id: uuid }
        expect(controller.send(:pre_checkin?)).to be false
      end
    end

    context 'when checkInType is not preCheckIn' do
      it 'returns false' do
        get :show, params: { id: uuid, checkInType: 'dayOf' }
        expect(controller.send(:pre_checkin?)).to be false
      end
    end

    context 'when session check_in_type is not preCheckIn' do
      it 'returns false' do
        post :create, params: { session: { uuid:, dob: '1970-01-01', last_name: 'Doe', check_in_type: 'dayOf' } }
        expect(controller.send(:pre_checkin?)).to be false
      end
    end
  end

  describe '#log_session_creation_attempt' do
    let(:session_data) do
      instance_double(
        CheckIn::V2::Session,
        uuid:,
        check_in_type: 'preCheckIn',
        facility_type: 'oh'
      )
    end

    before do
      allow(Flipper).to receive(:enabled?).with(:check_in_experience_detailed_logging).and_return(true)
    end

    context 'when flipper is enabled' do
      it 'logs session creation with pre-check-in workflow' do
        allow(controller).to receive(:pre_checkin?).and_return(true)

        expect(Rails.logger).to receive(:info).with(
          {
            message: 'Check-in session creation',
            check_in_uuid: uuid,
            check_in_type: 'preCheckIn',
            facility_type: 'oh',
            workflow: 'Pre-Check-In'
          }
        )

        controller.send(:log_session_creation_attempt, session_data)
      end

      it 'logs session creation with day-of-check-in workflow' do
        allow(controller).to receive(:pre_checkin?).and_return(false)

        expect(Rails.logger).to receive(:info).with(
          {
            message: 'Check-in session creation',
            check_in_uuid: uuid,
            check_in_type: 'preCheckIn',
            facility_type: 'oh',
            workflow: 'Day-Of-Check-In'
          }
        )

        controller.send(:log_session_creation_attempt, session_data)
      end
    end

    context 'when flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_detailed_logging).and_return(false)
      end

      it 'still logs when method is called directly' do
        allow(controller).to receive(:pre_checkin?).and_return(false)

        # The method itself always logs; the flipper check is in the controller action
        # to determine whether to call this method
        expect(Rails.logger).to receive(:info).with(
          {
            message: 'Check-in session creation',
            check_in_uuid: uuid,
            check_in_type: 'preCheckIn',
            facility_type: 'oh',
            workflow: 'Day-Of-Check-In'
          }
        )

        controller.send(:log_session_creation_attempt, session_data)
      end
    end
  end
end
