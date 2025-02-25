# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun::IngressBdnChunk, type: :worker do
  let(:bdn_clone) { create(:vye_bdn_clone_base) }
  let(:bdn_clone_id) { bdn_clone.id }
  let(:offset) { 0 }
  let(:block_size) { 10_000 }
  let(:filename) { 'test_0.txt' }
  let(:chunk) { instance_double(Vye::BatchTransfer::BdnChunk) }

  before do
    Sidekiq::Job.clear_all
  end

  it 'checks the existence of described_class' do
    expect(Vye::BatchTransfer::BdnChunk).to receive(:new).with(bdn_clone_id:, offset:, block_size:,
                                                               filename:).and_return(chunk)
    expect(chunk).to receive(:load)

    expect do
      described_class.perform_async(bdn_clone_id, offset, block_size, filename)
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain
  end
end
