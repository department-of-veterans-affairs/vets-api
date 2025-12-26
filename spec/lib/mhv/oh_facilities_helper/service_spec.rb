# frozen_string_literal: true

require 'rails_helper'
require 'mhv/oh_facilities_helper/service'

RSpec.describe MHV::OhFacilitiesHelper::Service do
  subject(:service) { described_class.new(user) }

  let(:user) { build(:user) }
  let(:va_treatment_facility_ids) { %w[516 553] }
  let(:pretransitioned_oh_facilities) { '516, 517, 518' }
  let(:facilities_ready_for_info_alert) { '553, 554' }
  let(:facilities_migrating_to_oh) { '554' }

  before do
    allow(user).to receive(:va_treatment_facility_ids).and_return(va_treatment_facility_ids)
    allow(Settings.mhv.oh_facility_checks).to receive_messages(
      pretransitioned_oh_facilities:,
      facilities_ready_for_info_alert:,
      facilities_migrating_to_oh:
    )
  end

  describe '#user_at_pretransitioned_oh_facility?' do
    context 'when user has a facility in pretransitioned OH facilities list' do
      let(:va_treatment_facility_ids) { %w[516 999] }

      it 'returns true' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when user has no facilities in pretransitioned OH facilities list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [516, 999] }

      it 'returns true' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end
  end

  describe '#user_facility_ready_for_info_alert?' do
    context 'when user has a facility in facilities ready for info alert list' do
      let(:va_treatment_facility_ids) { %w[553 999] }

      it 'returns true when user is behind feature toggle' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)
        expect(service.user_facility_ready_for_info_alert?).to be true
      end

      it 'returns false when user is not behind feature toggle' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        expect(service.user_facility_ready_for_info_alert?).to be false
      end

      it 'returns false when power switch is disabled, even if others are enabled' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)
        expect(service.user_facility_ready_for_info_alert?).to be false
      end

      it 'returns false when power switch is enabled, but all others disabled' do
        oh_feature_toggles = MHV::OhFacilitiesHelper::Service::OH_FEATURE_TOGGLES

        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        oh_feature_toggles.each do |toggle|
          allow(Flipper).to receive(:enabled?).with(toggle, user).and_return(false)
        end
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has no facilities in facilities ready for info alert list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [553, 999] }

      it 'returns true when user is behind feature toggles' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_labs_and_tests_enabled,
                                                  user).and_return(true)

        expect(service.user_facility_ready_for_info_alert?).to be true
      end

      it 'returns false when user is not behind feature toggles' do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)

        expect(service.user_facility_ready_for_info_alert?).to be false
      end
    end
  end

  describe '#user_facility_migrating_to_oh?' do
    context 'when user has a facility in migrating OH facilities list' do
      let(:va_treatment_facility_ids) { %w[516 554] }

      it 'returns true' do
        expect(service.user_facility_migrating_to_oh?).to be true
      end
    end

    context 'when user has no facilities in migrating OH facilities list' do
      let(:va_treatment_facility_ids) { %w[999 888] }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when user has nil va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { nil }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when user has empty va_treatment_facility_ids' do
      let(:va_treatment_facility_ids) { [] }

      it 'returns false' do
        expect(service.user_facility_migrating_to_oh?).to be false
      end
    end

    context 'when facility id is numeric and matches string in settings' do
      let(:va_treatment_facility_ids) { [516, 554] }

      it 'returns true' do
        expect(service.user_facility_migrating_to_oh?).to be true
      end
    end
  end

  describe 'Settings edge cases' do
    let(:va_treatment_facility_ids) { %w[516] }

    context 'when Settings value is nil' do
      let(:pretransitioned_oh_facilities) { nil }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is false' do
      let(:pretransitioned_oh_facilities) { false }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is 0' do
      let(:pretransitioned_oh_facilities) { 0 }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is an empty string' do
      let(:pretransitioned_oh_facilities) { '' }

      it 'returns false for user_at_pretransitioned_oh_facility?' do
        expect(service.user_at_pretransitioned_oh_facility?).to be false
      end
    end

    context 'when Settings value is a number (interpreted as facility ID)' do
      let(:pretransitioned_oh_facilities) { 516 }
      let(:va_treatment_facility_ids) { %w[516] }

      it 'returns true when user facility matches' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when Settings value has extra whitespace' do
      let(:pretransitioned_oh_facilities) { '  516  ,  517  ,  518  ' }

      it 'strips whitespace and matches correctly' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end

    context 'when Settings value has trailing comma' do
      let(:pretransitioned_oh_facilities) { '516,517,' }

      it 'handles trailing comma and matches correctly' do
        expect(service.user_at_pretransitioned_oh_facility?).to be true
      end
    end
  end
end
