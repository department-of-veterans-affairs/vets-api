# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AfterLoginJob do
  describe '#perform' do
    context 'with a user that has evss access' do
      let(:user) { create(:evss_user) }

      it 'launches CreateUserAccountJob' do
        expect(EVSS::CreateUserAccountJob).to receive(:perform_async)
        described_class.new.perform('user_uuid' => user.uuid)
      end
    end

    context 'with a user that doesnt have evss access' do
      let(:user) { create(:user) }

      it 'shouldnt launch CreateUserAccountJob' do
        expect(EVSS::CreateUserAccountJob).not_to receive(:perform_async)
        described_class.new.perform('user_uuid' => user.uuid)
      end
    end

    context 'in a non-staging environment' do
      let(:user) { create(:user) }

      around do |example|
        with_settings(Settings.test_user_dashboard, env: 'production') do
          example.run
        end
      end

      it 'does not call TUD account checkout' do
        expect_any_instance_of(TestUserDashboard::CheckoutUser).not_to receive(:call)
        described_class.new.perform('user_uuid' => user.uuid)
      end
    end

    context 'in a staging environment' do
      let(:user) { create(:user) }

      around do |example|
        with_settings(Settings.test_user_dashboard, env: 'staging') do
          example.run
        end
      end

      it 'calls TUD account checkout' do
        expect_any_instance_of(TestUserDashboard::CheckoutUser).to receive(:call)
        described_class.new.perform('user_uuid' => user.uuid)
      end
    end
  end
end
