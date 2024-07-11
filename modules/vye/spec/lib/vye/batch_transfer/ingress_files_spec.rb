# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::IngressFiles do
  describe '#bdn_feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:bdn_feed_filename)).to be_a(String)
    end
  end

  describe '#tims_feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:tims_feed_filename)).to be_a(String)
    end
  end

  it 'imports lines from BDN extract' do
    data = Vye::Engine.root / 'spec/fixtures/bdn_sample/WAVE.txt'
    expect do
      described_class.send(:bdn_import, data)
    end.to(
      change(Vye::UserProfile, :count).by(1).and(
        change(Vye::UserInfo, :count).by(1).and(
          change(Vye::Award, :count).by(1)
        )
      )
    )
  end

  it 'imports lines from TIMS extract' do
    data = Vye::Engine.root / 'spec/fixtures/tims_sample/tims32towave.txt'
    expect do
      described_class.send(:tims_import, data)
    end.to(
      change(Vye::UserProfile, :count).by(20).and(
        change(Vye::PendingDocument, :count).by(20)
      )
    )
  end

  it 'loads the BDN feed from AWS' do
    path = instance_double(Pathname)
    expect(Rails.root).to receive(:/).once.and_return(path)
    expect(Rails.root).to receive(:/).and_call_original

    allow(path).to receive(:basename)
    allow(path).to receive(:dirname).and_return(path)
    allow(path).to receive(:mkpath)
    expect(path).to receive(:delete)

    s3_client = instance_double(Aws::S3::Client)
    expect(described_class).to receive(:s3_client).and_return(s3_client)
    expect(s3_client).to receive(:get_object)

    expect(described_class).to receive(:bdn_import)

    described_class.bdn_load
  end

  it 'loads the TIMS feed from AWS' do
    path = instance_double(Pathname)
    expect(Rails.root).to receive(:/).once.and_return(path)
    expect(Rails.root).to receive(:/).and_call_original

    allow(path).to receive(:basename)
    allow(path).to receive(:dirname).and_return(path)
    allow(path).to receive(:mkpath)
    expect(path).to receive(:delete)

    s3_client = instance_double(Aws::S3::Client)
    expect(described_class).to receive(:s3_client).and_return(s3_client)
    expect(s3_client).to receive(:get_object)

    expect(described_class).to receive(:tims_import)

    described_class.tims_load
  end
end
