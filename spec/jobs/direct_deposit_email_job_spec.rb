# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectDepositEmailJob, type: :model do
  describe '#perform' do
    it 'sends a confirmation email' do
      mail = double('mail')
      allow(DirectDepositMailer).to receive(:build).with('test@example.com', 123_456_789).and_return(mail)
      expect(mail).to receive(:deliver_now)
      subject.perform('test@example.com', 123_456_789)
    end
  end
end
