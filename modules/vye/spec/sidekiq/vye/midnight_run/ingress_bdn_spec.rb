# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::MidnightRun::IngressBdn, type: :worker do
  let(:bdn_clone) { create(:vye_bdn_clone_base) }
  let(:chunks) do
    5.times.map do |i|
      double('Chunk',
             offset: i * 1000,
             block_size: 1000,
             filename: "file-#{i * 1000}.txt")
    end
  end
  let(:holiday_checker) { class_double(Vye::CloudTransfer).as_stubbed_const }
  let(:batch_double) { instance_double(Sidekiq::Batch, description: nil, on: nil) }

  before do
    Sidekiq::Job.clear_all
    allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
    allow(batch_double).to receive(:description=)
    allow(batch_double).to receive(:on)
    # Allow the jobs block to execute
    allow(batch_double).to receive(:jobs).and_yield
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
      allow(holiday_checker).to receive(:holiday?).and_return(false)
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect(Vye::BdnClone).to receive(:create!).and_return(bdn_clone)
      expect(Vye::BatchTransfer::BdnChunk).to receive(:build_chunks).and_return(chunks)

      worker = described_class.new
      worker.perform

      expect(Vye::MidnightRun::IngressBdnChunk).to have_enqueued_sidekiq_job.exactly(5).times
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2))
      allow(holiday_checker).to receive(:holiday?).and_return(true)
      allow(Vye::BdnClone).to receive(:create!).and_return(bdn_clone)
      allow(Vye::BatchTransfer::BdnChunk).to receive(:build_chunks).and_return(chunks)
    end

    after do
      Timecop.return
    end

    it 'logs holiday message and processes normally' do
      worker = described_class.new
      expect(Rails.logger).to receive(:info).with(/holiday detected, job run at:/).ordered
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: starting').ordered
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: finished').ordered

      worker.perform

      expect(Vye::MidnightRun::IngressBdnChunk).to have_enqueued_sidekiq_job.exactly(5).times
    end
  end

  context 'logging' do
    before do
      allow(holiday_checker).to receive(:holiday?).and_return(false)
      allow(Vye::BdnClone).to receive(:create!).and_return(double('BdnClone', id: 123))
      allow(Vye::BatchTransfer::BdnChunk).to receive(:build_chunks).and_return([])
    end

    it 'logs info' do
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: starting')
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: finished')

      described_class.new.perform
    end
  end
end
