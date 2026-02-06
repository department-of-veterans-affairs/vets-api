# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper::Instrumentation::AppointmentsEventSubscriber do
  context 'logs changes to toggle values' do
    it 'logs error for restricted operation of critical feature' do
      allow(Rails.logger).to receive(:error)
      Flipper.disable(:va_online_scheduling_subscriber_unit_testing) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(Rails.logger).to have_received(:error).with(
        'Restricted operation for critical appointments feature: disable va_online_scheduling_subscriber_unit_testing'
      )
    end

    it 'logs warning for routine operation of critical feature' do
      allow(Rails.logger).to receive(:warn)
      Flipper.enable(:va_online_scheduling_subscriber_unit_testing) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(Rails.logger).to have_received(:warn).with(
        'Routine operation for critical appointments feature: enable va_online_scheduling_subscriber_unit_testing'
      )
    end

    it 'logs info for restricted operation of non-critical feature' do
      allow(Rails.logger).to receive(:info)
      Flipper.disable(:va_online_scheduling_this_is_only_a_test) # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(Rails.logger).to have_received(:info).with(
        'Routine operation for appointments feature: disable va_online_scheduling_this_is_only_a_test'
      )
    end

    it 'logs info for routine operation of non-critical feature' do
      allow(Rails.logger).to receive(:info)
      Flipper.enable(:va_online_scheduling_this_is_only_a_test)  # rubocop:disable Project/ForbidFlipperToggleInSpecs
      expect(Rails.logger).to have_received(:info).with(
        'Routine operation for appointments feature: enable va_online_scheduling_this_is_only_a_test'
      )
    end
  end

  context 'does not log evaluation of toggle values' do
    it 'calls a non-modifying Flipper function' do
      expect(Rails.logger).not_to receive(:warn)
      expect(Rails.logger).not_to receive(:info)
      Flipper.enabled?(:va_online_scheduling_unit_testing)
      expect(Rails.logger).not_to receive(:warn)
      expect(Rails.logger).not_to receive(:info)
    end

    it 'modifies a unrelated feature' do
      expect(Rails.logger).not_to receive(:warn)
      expect(Rails.logger).not_to receive(:info)
      Flipper.enabled?(:this_is_only_a_test)
      expect(Rails.logger).not_to receive(:warn)
      expect(Rails.logger).not_to receive(:info)
    end
  end
end
