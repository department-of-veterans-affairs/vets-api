# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::AppointmentsController, type: :request do
  describe '#start_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { start: 'not a date', end: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:start_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#end_date' do
    context 'with an invalid date' do
      it 'throws an InvalidFieldValue exception' do
        subject.params = { end: 'not a date', start: '2022-09-21T00:00:00+00:00' }

        expect do
          subject.send(:end_date)
        end.to raise_error(Common::Exceptions::InvalidFieldValue)
      end
    end
  end

  describe '#create_draft' do
    let(:user) { build(:user, :vaos) }
    let(:referral_id) { '123456' }
    let(:cached_referral_data) do
      {
        provider_name: 'Test Provider',
        npi: '1234567890',
        network_id: 'network123',
        provider_id: 'provider123',
        appointment_type_id: 'type123',
        start_date: '2023-01-01',
        end_date: '2023-01-31'
      }
    end
    let(:draft_appointment) { OpenStruct.new(id: 'draft123') }
    let(:provider) { OpenStruct.new(id: 'provider123', location: { latitude: 38.8977, longitude: -77.0365 }) }
    let(:provider_search_result) { OpenStruct.new(provider_services: [provider]) }
    let(:slots) { [OpenStruct.new(id: 'slot123')] }

    before do
      redis_client = instance_double(Eps::RedisClient)
      allow(redis_client).to receive(:fetch_referral_attributes).and_return(cached_referral_data)

      appointment_service = instance_double(Eps::AppointmentService)
      allow(appointment_service).to receive(:create_draft_appointment).and_return(draft_appointment)

      provider_service = instance_double(Eps::ProviderService)
      allow(controller).to receive_messages(current_user: user, authorize_with_facilities: true,
                                            draft_params: { referral_id: }, eps_redis_client: redis_client, check_referral_data_validation: { success: true }, check_referral_usage: { success: true }, eps_appointment_service: appointment_service, eps_provider_service: provider_service)
      allow(provider_service).to receive_messages(search_provider_services: provider_search_result,
                                                  get_provider_slots: slots, get_drive_times: { provider.id => 15 })

      allow(Eps::DraftAppointmentSerializer).to receive(:new).and_return({ data: { id: 'draft123' } })
    end
  end
end
