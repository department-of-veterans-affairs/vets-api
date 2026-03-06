# frozen_string_literal: true

require 'rails_helper'
require 'flipper'
require 'ostruct'
require 'mhv_prescriptions_policy'
require 'mhv/account_creation/service'

describe MHVPrescriptionsPolicy do
  let(:mhv_prescriptions) { double('mhv_prescriptions') }
  let(:mhv_response) do
    {
      user_profile_id: '12345678',
      premium: true,
      champ_va:,
      patient:,
      sm_account_created: true,
      message: 'some-message'
    }
  end
  let(:patient) { false }
  let(:champ_va) { false }

  before do
    allow_any_instance_of(MHV::AccountCreation::Service).to receive(:create_account).and_return(mhv_response)
  end

  describe '#access?' do
    context 'when user is verified' do
      let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }

      context 'when user is a patient' do
        let(:patient) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'when user is champ_va eligible' do
        let(:champ_va) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'when user is both patient and champ_va eligible' do
        let(:patient) { true }
        let(:champ_va) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'when user is not a patient or champ_va eligible' do
        let(:patient) { false }
        let(:champ_va) { false }

        it 'returns false and logs access denial' do
          expect(Rails.logger).to receive(:info).with(
            'RX ACCESS DENIED',
            hash_including(
              mhv_id: anything,
              sign_in_service: anything,
              va_facilities: anything,
              va_patient: anything
            )
          )

          expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
        end
      end
    end

    context 'when user is not verified' do
      let(:user) { create(:user, :loa1) }

      it 'returns false and logs access denial' do
        expect(Rails.logger).to receive(:info).with(
          'RX ACCESS DENIED',
          hash_including(
            mhv_id: anything,
            sign_in_service: anything,
            va_facilities: anything,
            va_patient: anything
          )
        )

        expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
      end
    end

    context 'when user does not have mhv_correlation_id' do
      let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }

      before do
        allow(user).to receive(:mhv_correlation_id).and_return(nil)
      end

      it 'returns false and logs access denial' do
        expect(Rails.logger).to receive(:info).with(
          'RX ACCESS DENIED',
          hash_including(
            mhv_id: 'false',
            sign_in_service: anything,
            va_facilities: anything,
            va_patient: anything
          )
        )

        expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
      end
    end
  end
end
