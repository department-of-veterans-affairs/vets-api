# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::MidnightRun::IngressBdn, type: :worker do
  let(:bdn_clone) { FactoryBot.create(:vye_bdn_clone_base) }
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
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect(Vye::BdnClone).to receive(:create!).and_return(bdn_clone)
      expect(Vye::BatchTransfer::BdnChunk).to receive(:build_chunks).and_return(chunks)

      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain

      expect(Vye::MidnightRun::IngressBdnChunk).to have_enqueued_sidekiq_job.exactly(5).times
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not process BDNs' do
      expect(Vye::BdnClone).not_to receive(:create!)
      expect(Vye::BatchTransfer::BdnChunk).not_to receive(:build_chunks)

      described_class.new.perform
    end
  end
end
