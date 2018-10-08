# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AfterLoginJob do
  describe '#perform' do
    let(:user) { create(:evss_user) }

    it 'should launch CreateUserAccountJob' do
      expect(EVSS::CreateUserAccountJob).to receive(:perform_async).with(EVSS::AuthHeaders.new(user).to_h)
      described_class.new.perform(user.uuid)
    end
  end
end
