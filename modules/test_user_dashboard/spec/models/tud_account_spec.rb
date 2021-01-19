# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/models/test_user_dashboard/tud_account'

RSpec.describe TestUserDashboard::TudAccount, type: :model do
  subject { described_class.new(attributes) }

  describe 'without valid attributes' do
    context 'without a linked user account' do
      let(:attributes) { { standard: true, available: true, checkout_time: nil } }

      it 'is not valid' do
        expect(subject).not_to be_valid
      end
    end
  end
end
