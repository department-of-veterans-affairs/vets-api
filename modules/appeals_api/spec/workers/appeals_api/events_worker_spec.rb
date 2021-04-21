# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  RSpec.describe EventsWorker, type: :job do
    before do
      AppealsApi::Events::Handler.subscribe(:test_subscription, 'TestSubscriptionEvent')
    end

    describe 'perform' do
      it 'calls the correct callback' do
        test_double = instance_double('TestSubscriptionEvent')
        allow(test_double).to receive(:test_subscription)

        stub_const('TestSubscriptionEvent', test_double)

        allow(TestSubscriptionEvent).to receive(:new).and_return(test_double)

        EventsWorker.new.perform(:test_subscription, {})

        expect(test_double).to have_received(:test_subscription)
      end
    end
  end
end
