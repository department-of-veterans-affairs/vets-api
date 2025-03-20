# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::EpsAppointmentsController, type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:appointment_id) { 'qdm61cJ5' }
  let(:provider_id) { '9mN718pH' }
  let(:referral_number) { 'VA0000005681' }
  let(:provider_phone) { '555-123-4567' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'GET show' do
    context 'when called without authorization' do
      it 'throws unauthorized exception' do
        get "/vaos/v2/eps_appointments/#{appointment_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when appointment is in draft state' do
      let(:user) { build(:user, :vaos, :loa3) }
      let(:appointment) { OpenStruct.new(state: 'draft') }

      before do
        sign_in_as(user)
        allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointment)
          .with(appointment_id:, retrieve_latest_details: true)
          .and_return(appointment)
      end

      it 'returns 404 not found' do
        get "/vaos/v2/eps_appointments/#{appointment_id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when called with authorization' do
      let(:user) { build(:user, :vaos, :loa3) }
      let(:appointment) do
        OpenStruct.new(
          id: appointment_id,
          state: 'booked',
          provider_service_id: provider_id,
          referral: { referral_number: }
        )
      end
      let(:provider) do
        OpenStruct.new(
          id: provider_id,
          name: 'Dr. Smith',
          is_active: true,
          individual_providers: nil,
          provider_organization: nil,
          location: nil,
          network_ids: nil,
          scheduling_notes: nil,
          appointment_types: nil,
          specialties: nil,
          visit_mode: nil,
          features: nil
        )
      end
      let(:referral_detail) do
        build(:ccra_referral_detail, referral_number:, phone_number: provider_phone)
      end
      let(:serialized_response) do
        {
          data: {
            id: appointment_id,
            type: 'eps_appointment',
            attributes: {
              appointment: nil,
              provider: nil
            }
          }
        }.to_json
      end

      before do
        sign_in_as(user)
        allow_any_instance_of(Eps::AppointmentService).to receive(:get_appointment)
          .with(appointment_id:, retrieve_latest_details: true)
          .and_return(appointment)

        allow_any_instance_of(Eps::ProviderService).to receive(:get_provider_service)
          .with(provider_id:)
          .and_return(provider)

        # Set up serializer to return consistent JSON
        allow_any_instance_of(Eps::EpsAppointmentSerializer).to receive(:to_json)
          .and_return(serialized_response)
      end

      context 'when referral details are found with phone number' do
        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_number, '2')
            .and_return(referral_detail)
        end

        it 'fetches the referral detail and adds phone number to the provider' do
          expect_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_number, '2')

          expect_any_instance_of(VAOS::V2::EpsAppointmentsController).to receive(:fetch_provider_with_phone)
            .with(appointment, referral_detail)
            .and_call_original

          get "/vaos/v2/eps_appointments/#{appointment_id}"
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when referral service returns an error' do
        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_number, '2')
            .and_raise(StandardError.new('CCRA service error'))

          # The controller should log the error but continue
          allow(Rails.logger).to receive(:error)
        end

        it 'logs the error and continues without phone number' do
          expect(Rails.logger).to receive(:error).with(/Failed to retrieve referral details/)

          get "/vaos/v2/eps_appointments/#{appointment_id}"
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when referral number is not present' do
        let(:appointment) do
          OpenStruct.new(
            id: appointment_id,
            state: 'booked',
            provider_service_id: provider_id,
            referral: {}
          )
        end

        it 'does not try to fetch referral details' do
          expect_any_instance_of(Ccra::ReferralService).not_to receive(:get_referral)

          get "/vaos/v2/eps_appointments/#{appointment_id}"
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when provider service id is not present' do
        let(:appointment) do
          OpenStruct.new(
            id: appointment_id,
            state: 'booked',
            provider_service_id: nil,
            referral: { referral_number: }
          )
        end

        before do
          allow_any_instance_of(Ccra::ReferralService).to receive(:get_referral)
            .with(referral_number, '2')
            .and_return(referral_detail)
        end

        it 'returns nil for the provider' do
          expect_any_instance_of(Eps::ProviderService).not_to receive(:get_provider_service)

          get "/vaos/v2/eps_appointments/#{appointment_id}"
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
