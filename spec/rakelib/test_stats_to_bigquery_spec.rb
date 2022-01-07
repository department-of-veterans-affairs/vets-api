# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rakelib/test_stats_to_bigquery'

describe TestStatsToBigquery do
  let!(:bigquery) { double(dataset: dataset) }
  let!(:table) { double(insert: response) }
  let!(:dataset) { double(table: table) }
  let!(:response) { double(success?: true) }

  describe '#new' do
    context 'with valid Bigquery credentials' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
      end

      it 'creates a Bigquery instandce and looks up the dataset' do
        bigquery_instance = described_class.new
        expect(bigquery_instance.bigquery).to eql(bigquery)
        expect(bigquery_instance.dataset).to eql(bigquery.dataset)
        expect(bigquery_instance.failures).to eql([])
      end
    end

    context 'when there is a Bigquery issue' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_raise(RuntimeError)
      end

      it 'raises an exception' do
        expect(bigquery).not_to receive(:dataset)
        expect { described_class.new }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#upload_test_stats' do
    context 'when there are no failures' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
      end

      it 'uploads to Bigquery successfully' do
        expect($stdout).to receive(:puts).with('Uploaded RSpec data to BigQuery.')
        described_class.new.upload_test_stats
      end
    end

    context 'when there is at least one failure' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec_failure.xml'])
      end

      it 'uploads failure data' do
        expect($stdout).to receive(:puts).with('Uploaded RSpec data to BigQuery.')
        expect($stdout).to receive(:puts).with('Uploaded RSpec failure data to BigQuery.')
        described_class.new.upload_test_stats
      end
    end

    context 'when the upload fails' do
      let!(:response) { double(success?: false) }

      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
      end

      it 'raises an error' do
        expect { described_class.new.upload_test_stats }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#read_files' do
    context 'when there are no failures' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
      end

      it 'returns test statistics with no failures' do
        expect(described_class.new.read_files).to eq [{ date: '2021-12-14', total_tests: 803, total_failures: 0,
                                                        total_skipped: 0, total_time: 156 }]
      end
    end

    context 'when there is at least one failure' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec_failure.xml'])
      end

      it 'returns test statistics with one failure' do
        expect(described_class.new.read_files).to eq [{ date: '2021-12-14', total_tests: 1224, total_failures: 1,
                                                        total_skipped: 1, total_time: 118 }]
      end
    end
  end
end
