# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::MidnightRun::IngressTims, type: :worker do
  let(:chunks) do
    5.times.map do |i|
      offset = i * 1000
      block_size = 1000
      filename = "file-#{offset}.txt"
      Vye::BatchTransfer::Chunk.new(offset:, block_size:, filename:)
    end
  end

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect(Vye::BatchTransfer::TimsChunk).to receive(:build_chunks).and_return(chunks)

      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain

      expect(Vye::MidnightRun::IngressTimsChunk).to have_enqueued_sidekiq_job.exactly(5).times
    end

    context 'when BDN processing is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(true)
      end

      it 'does not enqueue anything' do
        expect(Vye::BatchTransfer::TimsChunk).not_to receive(:build_chunks)

        worker = described_class.new
        worker.perform

        expect(Vye::MidnightRun::IngressTimsChunk).to have_enqueued_sidekiq_job.exactly(0).times
      end
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not process TIMS' do
      expect(Vye::BatchTransfer::TimsChunk).not_to receive(:build_chunks)

      expect do
        described_class.new.perform
      end.not_to(change { Sidekiq::Worker.jobs.size })
    end
  end
end
