# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsService do
  subject(:service) { described_class.new(user) }

  let(:user) { build(:user, :mhv) }

  describe '#appointment_with_referral_exists?' do
    # Create a test service that lets us access the private method
    let(:service_with_exposed_method) do
      service_class = Class.new(VAOS::V2::AppointmentsService) do
        def public_appointment_with_referral_exists?(appointments, referral_id)
          appointment_with_referral_exists?(appointments, referral_id)
        end
      end
      service_class.new(user)
    end

    let(:referral_id) { 'REF-12345' }

    context 'when the appointments list is empty' do
      let(:appointments) { [] }

      it 'returns false' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(false)
      end
    end

    context 'when no appointment has a referral field' do
      let(:appointments) do
        [
          { id: 'appt-1', status: 'booked' },
          { id: 'appt-2', status: 'booked' }
        ]
      end

      it 'returns false' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(false)
      end
    end

    context 'when appointments have referrals but none match the target referral_id' do
      let(:appointments) do
        [
          { id: 'appt-1', referral: { referral_number: 'REF-99999' } },
          { id: 'appt-2', referral: { referral_number: 'REF-88888' } }
        ]
      end

      it 'returns false' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(false)
      end
    end

    context 'when one appointment has a matching referral' do
      let(:appointments) do
        [
          { id: 'appt-1', referral: { referral_number: 'REF-99999' } },
          { id: 'appt-2', referral: { referral_number: referral_id } }
        ]
      end

      it 'returns true' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(true)
      end
    end

    context 'when some appointments lack a referral field' do
      let(:appointments) do
        [
          { id: 'appt-1', status: 'booked' }, # No referral
          { id: 'appt-2', referral: { referral_number: referral_id } }
        ]
      end

      it 'handles nil referrals safely and returns true if any match is found' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(true)
      end
    end

    context 'when referral is present but referral_number is nil' do
      let(:appointments) do
        [
          { id: 'appt-1', referral: { some_other_field: 'value' } }, # referral present but no referral_number
          { id: 'appt-2', referral: { referral_number: nil } }
        ]
      end

      it 'returns false' do
        result = service_with_exposed_method.public_appointment_with_referral_exists?(appointments, referral_id)
        expect(result).to be(false)
      end
    end
  end
end 