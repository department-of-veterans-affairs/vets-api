# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AfterLoginJob do
  describe '#perform' do
    context 'with a user that has evss access' do
      let(:user) { create(:evss_user) }

      it 'launches CreateUserAccountJob' do
        expect(EVSS::CreateUserAccountJob).to receive(:perform_async).with(EVSS::AuthHeaders.new(user).to_h)
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
  end
end
