# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

RSpec.describe IvcChampva::OldRecordsCleanupJob, type: :job do
  let(:job) { described_class.new }
  let(:current_time) { Time.zone.now }
  # Small batch size for testing to reduce database records
  let(:test_batch_size) { 3 }

  before do
    allow(Settings.ivc_forms.sidekiq.old_records_cleanup_job).to receive(:enabled).and_return(true)
    allow(Rails.logger).to receive(:info)

    # Set up a fixed current time for testing
    Timecop.freeze(current_time)

    # Mock the batch size method to use a smaller size for testing
    allow(job).to receive(:get_batch_size).and_return(test_batch_size)
  end

  after do
    # Clean up Timecop
    Timecop.return
  end

  describe '#perform' do
    context 'when job is enabled' do
      before do
        # Create records with different ages
        create(:ivc_champva_form, updated_at: 70.days.ago)  # Should be deleted
        create(:ivc_champva_form, updated_at: 65.days.ago)  # Should be deleted
        create(:ivc_champva_form, updated_at: 61.days.ago)  # Should be deleted
        create(:ivc_champva_form, updated_at: 60.days.ago - 1.second)  # Should be deleted
        create(:ivc_champva_form, updated_at: 60.days.ago + 1.second)  # Should be kept
        create(:ivc_champva_form, updated_at: 59.days.ago)  # Should be kept
        create(:ivc_champva_form, updated_at: 30.days.ago)  # Should be kept
        create(:ivc_champva_form, updated_at: 10.days.ago)  # Should be kept
        create(:ivc_champva_form, updated_at: 1.day.ago)    # Should be kept
      end

      it 'deletes records older than 60 days' do
        expect do
          job.perform
        end.to change(IvcChampvaForm, :count).by(-4)

        # Verify only records newer than 60 days remain
        expect(IvcChampvaForm.where('updated_at < ?', 60.days.ago).count).to eq(0)
        expect(IvcChampvaForm.where('updated_at >= ?', 60.days.ago).count).to eq(5)
      end
    end

    context 'with batching' do
      before do
        # Create just 10 records which should be deleted
        10.times do |i|
          create(:ivc_champva_form, updated_at: (61 + i).days.ago)
        end

        # Create 5 records that should be kept (newer than 60 days)
        5.times do |i|
          create(:ivc_champva_form, updated_at: (59 - i).days.ago)
        end
      end

      it 'processes all records across multiple batches' do
        allow(job).to receive(:delete_old_records).and_call_original

        expect do
          job.perform
        end.to change(IvcChampvaForm, :count).by(-10)

        # With 10 records and a batch size of 3, we expect 4 batches (3+3+3+1)
        expect(job).to have_received(:delete_old_records).exactly(4).times
      end
    end

    context 'when job is disabled' do
      before do
        allow(Settings.ivc_forms.sidekiq.old_records_cleanup_job).to receive(:enabled).and_return(false)
        create_list(:ivc_champva_form, 3, updated_at: 70.days.ago)
      end

      it 'does not delete any records' do
        expect do
          job.perform
        end.not_to change(IvcChampvaForm, :count)
      end

      it 'does not log' do
        job.perform
        expect(Rails.logger).not_to have_received(:info)
      end
    end
  end

  describe '#get_batch_size' do
    it 'returns the configured batch size in production' do
      # Allow original method to run
      allow(job).to receive(:get_batch_size).and_call_original
      expect(job.send(:get_batch_size)).to eq(described_class::BATCH_SIZE)
    end

    it 'can be mocked for testing' do
      expect(job.send(:get_batch_size)).to eq(test_batch_size)
    end
  end

  describe '#find_old_records' do
    it 'returns only records older than 60 days' do
      # Create records with different ages
      old_records = [
        create(:ivc_champva_form, updated_at: 61.days.ago),
        create(:ivc_champva_form, updated_at: 90.days.ago)
      ]
      # These should not be returned
      create(:ivc_champva_form, updated_at: 59.days.ago)
      create(:ivc_champva_form, updated_at: 30.days.ago)

      result = job.send(:find_old_records)
      expect(result.count).to eq(2)
      expect(result.pluck(:id)).to match_array(old_records.map(&:id))
    end
  end

  describe '#find_old_records_in_batches' do
    it 'yields each batch to the block with correct size' do
      # Create just 8 records for testing batches
      8.times do |i|
        create(:ivc_champva_form, updated_at: (61 + i).days.ago)
      end

      batch_sizes = []
      job.send(:find_old_records_in_batches) do |batch|
        batch_sizes << batch.count
      end

      # We should have 3 batches with our test_batch_size of 3 (3+3+2)
      expect(batch_sizes.size).to eq(3)
      expect(batch_sizes[0]).to eq(test_batch_size)
      expect(batch_sizes[1]).to eq(test_batch_size)
      expect(batch_sizes[2]).to eq(2) # Remaining records
    end
  end
end
