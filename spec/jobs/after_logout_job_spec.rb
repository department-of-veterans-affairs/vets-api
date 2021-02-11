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
  end
end
