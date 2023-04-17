# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe CheckIn::TravelClaimSubmissionWorker, type: :worker do
  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:uuid) { '3bcd636c-d4d3-4349-9058-03b2f6b38ced' }
    let(:appointment_date) { '2022-09-01' }

    it 'does nothing' do
      Sidekiq::Testing.inline! do
        worker.perform(uuid, appointment_date)
      end
      expect(true).to be_truthy
    end
  end
end
