# frozen_string_literal: true
require 'rails_helper'

describe EVSS::GiBillStatus::ServiceFactory do
  describe '.get_service' do
    context 'when mock_gi_bill_status is true' do
      it 'returns a mock service' do
        expect(
          EVSS::GiBillStatus::ServiceFactory.get_service(user: nil, mock_service: true)
        ).to be_a(EVSS::GiBillStatus::MockService)
      end
    end
    context 'when mock_gi_bill_status is false' do
      let(:user) { FactoryGirl.create(:loa3_user) }
      it 'returns a real service' do
        expect(
          EVSS::GiBillStatus::ServiceFactory.get_service(user: user, mock_service: false)
        ).to be_a(EVSS::GiBillStatus::Service)
      end
    end
  end
end
