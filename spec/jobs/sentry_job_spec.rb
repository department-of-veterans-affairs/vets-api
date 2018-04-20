# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SentryJob do
  describe '#perform' do
    it 'should call Raven.send_event' do
      expect(Raven).to receive(:send_event)
      SentryJob.new.perform('my' => 'event')
    end
  end
end
