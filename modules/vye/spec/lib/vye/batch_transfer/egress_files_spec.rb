# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::EgressFiles do
  it 'sends address changes to AWS' do
    expect(described_class).to receive(:address_changes_filename)

    path = instance_double(Pathname)
    expect(Rails.root).to receive(:/).once.and_return(path)
    allow(path).to receive(:dirname).and_return(path)
    allow(path).to receive(:mkpath)
    expect(path).to receive(:open).and_yield(instance_double(IO))

    expect(described_class).to receive(:upload).with(path)

    described_class.address_changes_upload
  end

  it 'sends direct deposit changes to AWS' do
    expect(described_class).to receive(:direct_deposit_filename)

    path = instance_double(Pathname)
    expect(Rails.root).to receive(:/).once.and_return(path)
    allow(path).to receive(:dirname).and_return(path)
    allow(path).to receive(:mkpath)
    expect(path).to receive(:open).and_yield(instance_double(IO))

    expect(described_class).to receive(:upload).with(path)

    described_class.direct_deposit_upload
  end

  it 'sends verifications to AWS' do
    expect(described_class).to receive(:verification_filename)

    path = instance_double(Pathname)
    expect(Rails.root).to receive(:/).once.and_return(path)
    allow(path).to receive(:dirname).and_return(path)
    allow(path).to receive(:mkpath)
    expect(path).to receive(:open).and_yield(instance_double(IO))

    expect(described_class).to receive(:upload).with(path)

    described_class.verification_upload
  end
end
