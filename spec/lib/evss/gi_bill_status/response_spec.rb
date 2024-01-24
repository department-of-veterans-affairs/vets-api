# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Response do
  describe '#inspect' do
    context 'when the feature flag is on' do 
      before do
        allow(Flipper).to receive(:enabled?).with(:gibill_status_response_overwrite_inspect_method, nil).and_return(true)
      end

      it 'does not include @response=' do
        instance = EVSS::GiBillStatus::GiBillStatusResponse.new("200")
        inspect_output = instance.inspect

        expect(inspect_output).not_to include("@response=")
      end
    end

    context 'when the feature flag is off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:gibill_status_response_overwrite_inspect_method, nil).and_return(false)
      end

      it 'includes @response=' do
        instance = EVSS::GiBillStatus::GiBillStatusResponse.new("200")
        inspect_output = instance.inspect

        expect(inspect_output).to include("@response=")
      end
    end
  end
end