# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

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

  it 'checks the existence of described_class' do
    expect(Vye::BdnClone).to receive(:create!).and_return(bdn_clone)
    expect(Vye::BatchTransfer::BdnChunk).to receive(:build_chunks).and_return(chunks)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::MidnightRun::IngressBdnChunk).to have_enqueued_sidekiq_job.exactly(5).times
  end

  context 'logging' do
    before do
      allow(Vye::MidnightRun::IngressBdnChunk).to receive(:perform_in).and_return(nil)
    end

    # See comment in Vye::MidnightRun regarding logging. It applies here too.
    it 'logs info' do
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: starting')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#build_chunks starting')

      expect(Rails.logger).to receive(:info).with(
        'Vye::BatchTransfer::Chunking#initialize: filename=WAVE.txt, block_size=25000'
      )

      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunking#split starting')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#download: starting for WAVE.txt')

      string = 'Vye::BatchTransfer::Chunk#download: s3_client.get_object\(.*?/WAVE.txt, , scanned/WAVE.txt\)'
      expect(Rails.logger).to receive(:info).with(a_string_matching(string))

      string = %r{Vye::BatchTransfer::Chunk#initialize: offset=0, block_size=25000, file=.*?/WAVE_0\.txt, filename=}
      expect(Rails.logger).to receive(:info).with(a_string_matching(string))

      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#initialize: finished')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#download: finished')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunking#split complete')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#build_chunks: returning chunks')
      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunking#initialize complete')
      expect(Rails.logger).to receive(:info).with('Vye::MidnightRun::IngressBdn: completed')

      Vye::MidnightRun::IngressBdn.new.perform
    end
  end
end
