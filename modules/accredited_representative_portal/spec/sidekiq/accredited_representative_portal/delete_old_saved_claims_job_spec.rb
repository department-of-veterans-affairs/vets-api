# frozen_string_literal: true

require 'rails_helper'

# Test subclass to avoid stubbing
class TestDeleteOldSavedClaimsJob < AccreditedRepresentativePortal::DeleteOldSavedClaimsJob
  attr_reader :test_relation

  def initialize(test_relation: nil)
    @test_relation = test_relation
    super()
  end

  def enabled?
    true
  end

  def scope
    test_relation || super
  end

  def statsd_key_prefix
    'test.prefix'
  end

  def log_label
    'TestLabel'
  end
end

RSpec.describe AccreditedRepresentativePortal::DeleteOldSavedClaimsJob do
  # Use the subclass and inject relation
  subject(:job) { TestDeleteOldSavedClaimsJob.new(test_relation: relation) }

  let(:relation) { instance_double(ActiveRecord::Relation) }
  let(:record) { instance_double(ActiveRecord::Base) }

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when deleting records successfully' do
      before do
        allow(relation).to receive(:where).and_return(relation)
        allow(relation).to receive(:find_each).and_yield(record)
        allow(record).to receive(:destroy)
      end

      it 'increments success StatsD and logs' do
        job.perform

        expect(StatsD).to have_received(:increment).with('test.prefix.count', 1)
        expect(Rails.logger).to have_received(:info).with(/deleted 1 old TestLabel records/)
      end
    end

    context 'when an ActiveRecord error occurs' do
      before do
        allow(relation).to receive(:where).and_return(relation)
        allow(relation).to receive(:find_each)
          .and_raise(ActiveRecord::ActiveRecordError.new('boom'))
      end

      it 'increments StatsD error and logs without raising' do
        expect { job.perform }.not_to raise_error

        expect(StatsD).to have_received(:increment).with('test.prefix.error')
        expect(Rails.logger).to have_received(:error)
          .with(/DeleteOldSavedClaimsJob perform exception: ActiveRecord::ActiveRecordError boom/)
      end
    end
  end
end
