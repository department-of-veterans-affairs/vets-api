# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::BigQuery do
  let!(:bigquery) { double(query: true, dataset: dataset) }
  let!(:dataset) { double(table: true) }

  before do
    allow(Google::Cloud::Bigquery).to receive(:configure).and_return(true)
    allow(Google::Cloud::Bigquery).to receive(:new).and_return(bigquery)
  end

  describe '#initialize' do
    context 'when Bigquery is initialized without errors' do
      it 'sets the bigquery instance variable' do
        expect(TestUserDashboard::BigQuery.new.bigquery).to eq(bigquery)
      end
    end

    context 'when Bigquery raises an exception' do
      it 'logs an exception to Sentry' do
        allow(Google::Cloud::Bigquery).to receive(:new).and_raise('error')
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry)
        TestUserDashboard::BigQuery.new
      end
    end
  end

  describe '#delete_from' do
    let!(:table_name) { 'test_table_name' }

    context 'when the query succeeds' do
      it 'queries Bigquery withour errors' do
        expect(bigquery).to receive(:query)
        TestUserDashboard::BigQuery.new.delete_from(table_name: table_name)
      end
    end

    context 'when the query fails' do
      it 'logs an exception to Sentry' do
        allow(bigquery).to receive(:query).and_raise('error')
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        TestUserDashboard::BigQuery.new.delete_from(table_name: table_name)
      end
    end
  end

  describe '#insert_into' do
    let!(:table_name) { 'test_table_name' }
    let!(:rows) { [{ row: 'test_data' }] }

    context 'when the Bigquery insertion succeeds' do
      it 'inserts data into the Bigquery table' do
        expect(dataset).to receive(:table)
        TestUserDashboard::BigQuery.new.insert_into(table_name: table_name, rows: rows)
      end
    end

    context 'when the insertion fails' do
      it 'logs an exception to Sentry' do
        allow(dataset).to receive(:table).and_raise('error')
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        TestUserDashboard::BigQuery.new.insert_into(table_name: table_name, rows: rows)
      end
    end
  end
end
