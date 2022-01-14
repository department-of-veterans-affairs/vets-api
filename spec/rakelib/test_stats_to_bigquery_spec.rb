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

  describe '#upload_stats_data' do
    context 'when there are no failures' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
      end

      it 'uploads to Bigquery successfully' do
        expect(described_class.new.upload_stats_data).to eql('Uploaded RSpec statistics data to BigQuery.')
      end
    end

    context 'when the upload fails' do
      let!(:response) { double(success?: false) }

      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
      end

      it 'raises an error' do
        expect { described_class.new.upload_stats_data }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#upload_coverage_data' do
    before do
      allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
      allow(File).to receive(:read).and_return(File.read('spec/rakelib/fixtures/index.html'))
    end

    context 'when there are no failures' do
      it 'uploads to Bigquery successfully' do
        expect(described_class.new.upload_coverage_data).to eql('Uploaded RSpec test coverage data to BigQuery.')
      end
    end

    context 'when the upload fails' do
      let!(:response) { double(success?: false) }

      it 'raises an error' do
        expect { described_class.new.upload_coverage_data }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#upload_failure_data' do
    before do
      allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
      allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec.xml'])
    end

    context 'when there are no failures' do
      it 'does not upload failure data' do
        test_stats_to_bigquery = described_class.new
        test_stats_to_bigquery.upload_stats_data
        expect(test_stats_to_bigquery.upload_failure_data).to eql('No failures to upload to BigQuery.')
      end
    end

    context 'when there is at least one failure' do
      before do
        allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
        allow(Dir).to receive(:"[]").and_return(['spec/rakelib/fixtures/rspec_failure.xml'])
      end

      it 'uploads failure data' do
        test_stats_to_bigquery = described_class.new
        test_stats_to_bigquery.upload_stats_data
        expect(test_stats_to_bigquery.upload_failure_data).to eql('Uploaded RSpec failure data to BigQuery.')
      end
    end
  end
end
