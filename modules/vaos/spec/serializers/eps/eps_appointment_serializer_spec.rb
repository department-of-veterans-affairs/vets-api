# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::EpsAppointmentSerializer do
  let(:provider) do
    double(
      id: '1',
      name: 'Dr. Smith',
      is_active: true,
      individual_providers: ['Dr. Jones', 'Dr. Williams'],
      provider_organization: 'Medical Group',
      location: { address: '123 Medical St' },
      network_ids: ['sandbox-network-5vuTac8v'],
      scheduling_notes: 'Available weekdays',
      appointment_types: [
        {
          id: 'ov',
          name: 'Office Visit',
          is_self_schedulable: true
        }
      ],
      specialties: [
        {
          id: '208800000X',
          name: 'Urology'
        }
      ],
      visit_mode: 'in-person',
      features: {
        is_digital: true
      }
    )
  end

  let(:appointment) do
    {
      id: 123,
      appointment_details: { status: 'booked', last_retrieved: '2023-10-01T00:00:00Z', start: '2023-10-10T10:00:00Z' },
      referral: { referral_number: '12345' },
      patient_id: '1234567890V123456',
      network_id: 'network_1',
      provider_service_id: 'clinic_1',
      contact: 'contact_info'
    }
  end

  let(:eps_appointment) do
    double(
      id: 123,
      appointment: appointment,
      provider: provider
    )
  end

  describe '#serializable_hash' do
    subject(:serialized_json) { described_class.new(eps_appointment).serializable_hash }

    it 'has the correct structure' do
      expect(serialized_json).to include(
        data: {
          id: '123',
          type: :eps_appointment,
          attributes: {
            appointment: {
              id: '123',
              status: 'booked',
              patient_icn: '1234567890V123456',
              created: '2023-10-01T00:00:00Z',
              location_id: 'network_1',
              clinic: 'clinic_1',
              start: '2023-10-10T10:00:00Z',
              contact: 'contact_info',
              referral_id: '12345',
              referral: {
                referral_number: '12345'
              }
            },
            provider: {
              id: '1',
              name: 'Dr. Smith',
              is_active: true,
              individual_providers: ['Dr. Jones', 'Dr. Williams'],
              provider_organization: 'Medical Group',
              location: { address: '123 Medical St' },
              network_ids: ['sandbox-network-5vuTac8v'],
              scheduling_notes: 'Available weekdays',
              appointment_types: [
                {
                  id: 'ov',
                  name: 'Office Visit',
                  is_self_schedulable: true
                }
              ],
              specialties: [
                {
                  id: '208800000X',
                  name: 'Urology'
                }
              ],
              visit_mode: 'in-person',
              features: {
                is_digital: true
              }
            }
          }
        }
      )
    end

    describe 'appointment' do
      context 'when appointment is nil' do
        let(:appointment) { nil }

        it 'returns nil for appointment' do
          appointment_data = serialized_json.dig(:data, :attributes, :appointment)
          expect(appointment_data).to be_nil
        end
      end

      it 'includes appointment details' do
        appointment_data = serialized_json.dig(:data, :attributes, :appointment)
        expect(appointment_data).to include(
          id: '123',
          status: 'booked',
          patient_icn: '1234567890V123456',
          created: '2023-10-01T00:00:00Z',
          location_id: 'network_1',
          clinic: 'clinic_1',
          start: '2023-10-10T10:00:00Z',
          contact: 'contact_info',
          referral_id: '12345',
          referral: {
            referral_number: '12345'
          }
        )
      end
    end

    describe 'provider' do
      context 'when provider is nil' do
        let(:provider) { nil }

        it 'returns nil for provider' do
          provider_data = serialized_json.dig(:data, :attributes, :provider)
          expect(provider_data).to be_nil
        end
      end

      it 'includes provider details' do
        provider_data = serialized_json.dig(:data, :attributes, :provider)
        expect(provider_data).to include(
          id: '1',
          name: 'Dr. Smith',
          is_active: true,
          individual_providers: [
            'Dr. Jones',
            'Dr. Williams'
          ]
        )
      end
    end
  end
end
