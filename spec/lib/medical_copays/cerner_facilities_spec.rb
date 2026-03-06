# frozen_string_literal: true

require 'rails_helper'
require 'medical_copays/cerner_facilities'

RSpec.describe MedicalCopays::CernerFacilities do
  describe '.cerner_copay_user?' do
    let(:user) { build(:user, :loa3) }

    context 'when the user has existing cerner facility IDs from MPI' do
      before do
        allow(user).to receive_messages(cerner_facility_ids: %w[757], vha_facility_ids: %w[999])
      end

      it 'returns true' do
        expect(described_class.cerner_copay_user?(user)).to be true
      end
    end

    context 'when the user has a future cerner facility' do
      before do
        allow(user).to receive_messages(cerner_facility_ids: [], vha_facility_ids: %w[553])
      end

      it 'returns true' do
        expect(described_class.cerner_copay_user?(user)).to be true
      end
    end

    context 'when the user has a future cerner facility with mixed-type IDs' do
      before do
        allow(user).to receive_messages(cerner_facility_ids: [], vha_facility_ids: ['553', 553, '999'])
      end

      it 'returns true' do
        expect(described_class.cerner_copay_user?(user)).to be true
      end
    end

    context 'when the user has no cerner or future cerner facilities' do
      before do
        allow(user).to receive_messages(cerner_facility_ids: [], vha_facility_ids: %w[999])
      end

      it 'returns false' do
        expect(described_class.cerner_copay_user?(user)).to be false
      end
    end

    context 'when the user has nil cerner facility IDs' do
      before do
        allow(user).to receive_messages(cerner_facility_ids: nil, vha_facility_ids: %w[999])
      end

      it 'returns false' do
        expect(described_class.cerner_copay_user?(user)).to be false
      end
    end
  end
end
