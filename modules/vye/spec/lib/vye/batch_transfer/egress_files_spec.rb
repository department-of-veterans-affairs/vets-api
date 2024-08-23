# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::EgressFiles do
  let(:file) { instance_double(Pathname) }
  let(:io) { instance_double(IO) }

  it 'sends address changes to AWS' do
    expect(described_class).to receive(:address_changes_filename)
    expect(described_class).to receive(:tmp_path).and_return(file)
    expect(file).to receive(:open).and_yield(io)
    expect(described_class).to receive(:upload).with(file)
    expect(file).to receive(:delete)

    described_class.address_changes_upload
  end

  it 'sends direct deposit changes to AWS' do
    expect(described_class).to receive(:direct_deposit_filename)
    expect(described_class).to receive(:tmp_path).and_return(file)
    expect(file).to receive(:open).and_yield(io)
    expect(described_class).to receive(:upload).with(file)
    expect(file).to receive(:delete)

    described_class.direct_deposit_upload
  end

  it 'sends verifications to AWS' do
    expect(described_class).to receive(:verification_filename)
    expect(described_class).to receive(:tmp_path).and_return(file)
    expect(file).to receive(:open).and_yield(io)
    expect(described_class).to receive(:upload).with(file)
    expect(file).to receive(:delete)

    described_class.verification_upload
  end
end
