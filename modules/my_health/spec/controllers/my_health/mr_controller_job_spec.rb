# frozen_string_literal: true

require 'rails_helper'

Sidekiq::Testing.fake!

RSpec.describe MyHealth::MRController, type: :controller do
  let(:user) { create(:user, :loa3) }

  before do
    sign_in_as(user)
    controller.instance_variable_set(:@current_user, user)
  end

  describe 'background job integration' do
    context 'when using OH data path' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_oh_lab_type_logging_enabled,
                                                  user).and_return(true)
        allow(controller).to receive(:params).and_return({ use_oh_data_path: '1' })
      end

      it 'enqueues the UnifiedHealthData::LabsRefreshJob when accessing client' do
        expect(UnifiedHealthData::LabsRefreshJob).to receive(:perform_async).with(user.uuid)

        # This will trigger the client method which should enqueue the job
        controller.send(:client)
      end
    end

    context 'when using Vista data path' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_vista_lab_type_logging_enabled,
                                                  user).and_return(true)
        allow(controller).to receive(:params).and_return({ use_oh_data_path: '0' })
      end

      it 'enqueues the UnifiedHealthData::LabsRefreshJob when accessing client' do
        expect(UnifiedHealthData::LabsRefreshJob).to receive(:perform_async).with(user.uuid)

        # This will trigger the client method which should enqueue the job
        controller.send(:client)
      end
    end

    context 'when feature toggles are disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_enabled, user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_oh_lab_type_logging_enabled,
                                                  user).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:mhv_accelerated_delivery_uhd_vista_lab_type_logging_enabled,
                                                  user).and_return(false)
      end

      it 'does not enqueue the UnifiedHealthData::LabsRefreshJob' do
        expect(UnifiedHealthData::LabsRefreshJob).not_to receive(:perform_async)

        # This will trigger the client method which should not enqueue the job
        controller.send(:client)
      end
    end
  end
end
