# frozen_string_literal: true

require 'rails_helper'
require 'flipper'
require 'ostruct'
require 'mhv_prescriptions_policy'

describe MHVPrescriptionsPolicy do
  let(:mhv_prescriptions) { double('mhv_prescriptions') }
  let(:user) do
    u = OpenStruct.new(
      mhv_user_account: OpenStruct.new(patient: true),
      mhv_account_type: 'Premium',
      va_patient: true,
      va_treatment_facility_ids: ['123'],
      mhv_correlation_id: '456',
      identity: OpenStruct.new(sign_in: { service_name: 'idme' })
    )
    def u.va_patient?
      va_patient
    end
    u
  end

  def set_va_patient(user, value)
    user.va_patient = value
  end

  context 'when Flipper flag is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_new_policy, user).and_return(true)
    end

    it 'returns true if user is a patient' do
      expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
    end

    it 'returns false if user is not a patient' do
      user.mhv_user_account.patient = false
      expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
    end
  end

  context 'when Flipper flag is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medications_new_policy, user).and_return(false)
    end

    it 'returns true for Premium/Advanced account and va_patient' do
      user.mhv_account_type = 'Premium'
      set_va_patient(user, true)
      expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
    end

    it 'returns true for Premium/Advanced account and MHV sign in' do
      user.mhv_account_type = 'Advanced'
      set_va_patient(user, false)
      user.identity.sign_in[:service_name] = 'myhealthevet'
      stub_const('SignIn::Constants::Auth::MHV', 'myhealthevet')
      expect(described_class.new(user, mhv_prescriptions).access?).to be(true)
    end

    it 'returns false for Basic account' do
      user.mhv_account_type = 'Basic'
      set_va_patient(user, true)
      expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
    end

    it 'returns false for Premium/Advanced account but not va_patient and not MHV sign in' do
      user.mhv_account_type = 'Premium'
      set_va_patient(user, false)
      user.identity.sign_in[:service_name] = 'idme'
      stub_const('SignIn::Constants::Auth::MHV', 'myhealthevet')
      expect(described_class.new(user, mhv_prescriptions).access?).to be(false)
    end
  end
end
