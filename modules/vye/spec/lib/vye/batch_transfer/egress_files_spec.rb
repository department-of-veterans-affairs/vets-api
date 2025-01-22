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

  describe '#verification_filename' do
    around do |example|
      Timecop.freeze(time) { example.run }
    end

    let(:central_timezone) { 'Central Time (US & Canada)' }

    context 'on first day of the year' do
      let(:time) { Time.find_zone(central_timezone).local(2024, 1, 1, 12, 0, 0) }

      it 'pads with zeros' do
        expect(described_class.send(:verification_filename)).to eq('vawave001')
      end
    end

    context 'on day 99 of the year' do
      let(:time) { Time.find_zone(central_timezone).local(2024, 4, 8, 12, 0, 0) }

      it 'pads with zeros' do
        expect(described_class.send(:verification_filename)).to eq('vawave099')
      end
    end

    context 'on last day of a leap year' do
      let(:time) { Time.find_zone(central_timezone).local(2024, 12, 31, 12, 0, 0) }

      it 'handles day 366' do
        expect(described_class.send(:verification_filename)).to eq('vawave366')
      end
    end

    context 'on last day of a non-leap year' do
      let(:time) { Time.find_zone(central_timezone).local(2023, 12, 31, 12, 0, 0) }

      it 'handles day 365' do
        expect(described_class.send(:verification_filename)).to eq('vawave365')
      end
    end
  end
end
