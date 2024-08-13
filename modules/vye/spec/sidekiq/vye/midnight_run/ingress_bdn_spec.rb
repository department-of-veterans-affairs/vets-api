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
end
