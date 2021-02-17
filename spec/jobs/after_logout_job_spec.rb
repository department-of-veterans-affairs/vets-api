# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AfterLogoutJob do
  describe '#perform' do
    context 'without an account_uuid' do
      let(:user) { create(:user) }

      it 'immediately returns' do
        expect_any_instance_of(TestUserDashboard::CheckinUser).not_to receive(:call)
        described_class.new.perform('account_uuid' => '')
      end
    end

    context 'with an account_uuid' do
      let(:user) { create(:user) }

      it 'calls TestUserDashboard CheckinUser' do
        expect_any_instance_of(TestUserDashboard::CheckinUser).to receive(:call)
        described_class.new.perform('account_uuid' => user.account_uuid)
      end
    end
  end
end
