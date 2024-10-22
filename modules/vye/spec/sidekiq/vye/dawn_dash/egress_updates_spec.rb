# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::DawnDash::EgressUpdates, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  it 'checks the existence of described_class' do
    expect(Vye::BatchTransfer::EgressFiles).to receive(:address_changes_upload)
    expect(Vye::BatchTransfer::EgressFiles).to receive(:direct_deposit_upload)
    expect(Vye::BatchTransfer::EgressFiles).to receive(:verification_upload)
    expect(Vye::BdnClone).to receive(:clear_export_ready!)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain
  end

  # describe 'logging' do
  #   allow 
  #   include_examples 'logging behavior', [
  #     { log_level: :info, text: 'Vye::DawnDash::EgressUpdates starting' },
  #     { log_level: :info, text: 'Vye::DawnDash::EgressUpdates finished' }
  #   ]
  # end
end
