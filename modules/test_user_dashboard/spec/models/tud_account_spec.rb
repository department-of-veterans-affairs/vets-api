# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::TudAccount do
  let(:tud_account) { create(:tud_account) }

  describe '#available?' do
    context 'checked out' do
      before { tud_account.checkout_time = Time.current }

      it { expect(tud_account.available?).to be(false) }
    end

    context 'checked in' do
      before { tud_account.checkout_time = nil }

      it { expect(tud_account.available?).to be(true) }
    end
  end
end
