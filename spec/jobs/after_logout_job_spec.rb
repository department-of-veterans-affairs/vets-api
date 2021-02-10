# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AfterLogoutJob do
  describe '#perform' do
    context 'without an account_uuid' do
      let(:user) { create(:user) }

      it 'does returns' do
        expect_any_instance_of(TestUserDashboard::CheckinUser).not_to receive(:call)
        described_class.new.perform('account_uuid' => '')
      end
    end

    context 'in a production environment' do
      let(:user) { create(:user) }

      it 'does not call TUD account checkin' do
        expect(Rails.env).to receive('production?').once.and_return(true)
        expect_any_instance_of(TestUserDashboard::CheckinUser).not_to receive(:call)
        described_class.new.perform('account_uuid' => user.account_uuid)
      end
    end

    context 'in a non-production environment' do
      let(:user) { create(:user) }

      it 'calls TUD account checkin' do
        expect(Rails.env).to receive('production?').once.and_return(false)
        expect_any_instance_of(TestUserDashboard::CheckinUser).to receive(:call)
        described_class.new.perform('account_uuid' => user.account_uuid)
      end
    end
  end
end
