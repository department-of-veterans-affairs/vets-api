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

  context 'when Flipper flag is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_new_policy, user).and_return(true)
    end

    context 'and user is verified' do
      let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }

      context 'and user is a patient' do
        let(:patient) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'and user is champ_va eligible' do
        let(:champ_va) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'and user is not a patient or champ_va eligible' do
        let(:patient) { false }
        let(:champ_va) { false }

        it 'returns false' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
        end
      end
    end

    context 'and user is not verified' do
      let(:user) { create(:user, :loa1) }

      it 'returns false' do
        expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
      end
    end
  end

  context 'when Flipper flag is disabled' do
    let(:user) { create(:user, :loa3, va_patient:, authn_context:) }
    let(:mhv_account_type) { 'some-mhv-account-type' }
    let(:authn_context) { LOA::IDME_MHV_LOA1 }
    let(:va_patient) { true }

    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_new_policy, user).and_return(false)
      allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    end

    context 'and user is mhv_account_type premium' do
      let(:mhv_account_type) { 'Premium' }

      context 'and user is a va patient' do
        let(:va_patient) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'and user is not a va patient' do
        let(:va_patient) { false }

        context 'and user has logged in with MHV credential' do
          let(:authn_context) { LOA::IDME_MHV_LOA1 }

          it 'returns true' do
            expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
          end
        end

        context 'and user has not logged in with MHV credential' do
          let(:authn_context) { LOA::IDME_LOA1_VETS }

          it 'returns true' do
            expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
          end
        end
      end
    end

    context 'and user is mhv_account_type advanced' do
      let(:mhv_account_type) { 'Advanced' }

      context 'and user is a va patient' do
        let(:va_patient) { true }

        it 'returns true' do
          expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
        end
      end

      context 'and user is not a va patient' do
        let(:va_patient) { false }

        context 'and user has logged in with MHV credential' do
          let(:authn_context) { LOA::IDME_MHV_LOA1 }

          it 'returns true' do
            expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
          end
        end

        context 'and user has not logged in with MHV credential' do
          let(:authn_context) { LOA::IDME_LOA1_VETS }

          it 'returns true' do
            expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
          end
        end
      end
    end

    context 'and user mhv_account_type is arbitrary' do
      let(:mhv_account_type) { 'some-mhv-account-type' }

      it 'returns false' do
        expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
      end
    end
  end
end
