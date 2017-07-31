# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::ServiceFactory do
  describe '.get_service' do
    let(:user) { FactoryGirl.create(:loa3_user) }

    context 'when mock_letters is true' do
      it 'returns a mock service' do
        expect(
          EVSS::Letters::ServiceFactory.get_service(mock_service: true)
        ).to be_a(EVSS::Letters::MockService)
      end
    end
    context 'when mock_letters is false' do
      it 'returns a real service' do
        expect(
          EVSS::Letters::ServiceFactory.get_service(mock_service: false)
        ).to be_a(EVSS::Letters::Service)
      end
    end
  end
end
