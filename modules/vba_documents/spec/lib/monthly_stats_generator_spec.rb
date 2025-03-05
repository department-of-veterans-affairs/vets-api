# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/monthly_stats_generator'

RSpec.describe VBADocuments::MonthlyStatsGenerator do
  describe '#initialize' do
    it 'sets all instance variables' do
      stats_generator = described_class.new(month: 12, year: 2023)
      expect(stats_generator.instance_variable_get(:@month)).to eq(12)
      expect(stats_generator.instance_variable_get(:@year)).to eq(2023)
    end

    it 'raises an ArgumentError when the month is nil' do
      expect { described_class.new(month: nil, year: 2023) }
        .to raise_error(ArgumentError, 'Month and year not provided')
    end

    it 'raises an ArgumentError when the year is nil' do
      expect { described_class.new(month: 12, year: nil) }
        .to raise_error(ArgumentError, 'Month and year not provided')
    end

    it 'raises an ArgumentError when the month is not valid' do
      expect { described_class.new(month: 'December', year: 2023) }
        .to raise_error(ArgumentError, 'Month and year not valid')
    end

    it 'raises an ArgumentError when the year is not valid' do
      expect { described_class.new(month: 12, year: 23) }
        .to raise_error(ArgumentError, 'Month and year not valid')
    end
  end

  describe '#generate_and_save_stats' do
    let(:month) { DateTime.now.month }
    let(:year) { DateTime.now.year }
    let(:expected_stats_result) do
      {
        'summary_stats' => {
          'total' => 13,
          'vbms_count' => 2,
          'error_percent' => 0.23,
          'errored_count' => 3,
          'expired_count' => 2,
          'success_count' => 2,
          'processing_count' => 4
        },
        'consumer_stats' => [
          {
            'total' => 8,
            'vbms_count' => 1,
            'consumer_name' => 'Consumer1',
            'error_percent' => 0.13,
            'errored_count' => 1,
            'expired_count' => 1,
            'success_count' => 1,
            'processing_count' => 4
          },
          {
            'total' => 5,
            'vbms_count' => 1,
            'consumer_name' => 'Consumer2',
            'error_percent' => 0.4,
            'errored_count' => 2,
            'expired_count' => 1,
            'success_count' => 1,
            'processing_count' => 0
          }
        ],
        'page_count_stats' => {
          'mode' => 2,
          'total' => 125,
          'median' => 2.0,
          'average' => 12.5,
          'maximum' => 103
        },
        'upload_size_in_mb_stats' => {
          'mode' => 0.79,
          'median' => 0.78,
          'average' => 2.7,
          'maximum' => 20.89
        },
        'status_elapsed_time_stats' => {
          'pending' => {
            'total' => 10,
            'median' => '00:00:01',
            'average' => '00:00:02',
            'maximum' => '00:00:12',
            'minimum' => '00:00:00'
          },
          'success' => {
            'total' => 2,
            'median' => '08:58:21',
            'average' => '08:58:21',
            'maximum' => '10:56:37',
            'minimum' => '07:00:06'
          },
          'received' => {
            'total' => 5,
            'median' => '00:33:22',
            'average' => '00:34:18',
            'maximum' => '01:02:12',
            'minimum' => '00:06:23'
          },
          'uploaded' => {
            'total' => 9,
            'median' => '00:00:02',
            'average' => '00:00:02',
            'maximum' => '00:00:05',
            'minimum' => '00:00:01'
          },
          'processing' => {
            'total' => 4,
            'median' => '00:00:05',
            'average' => '00:05:21',
            'maximum' => '00:21:16',
            'minimum' => '00:00:00'
          },
          'pending_to_vbms' => {
            'total' => 2,
            'average' => '10:00:37',
            'maximum' => '11:58:42',
            'minimum' => '08:02:32'
          },
          'success_to_vbms' => {
            'total' => 2,
            'average' => '08:58:21',
            'maximum' => '10:56:37',
            'minimum' => '07:00:06'
          },
          'pending_to_error' => {
            'total' => 3,
            'average' => '00:00:01',
            'maximum' => '00:00:02',
            'minimum' => '00:00:01'
          },
          'pending_to_success' => {
            'total' => 4,
            'average' => '00:46:27',
            'maximum' => '01:02:26',
            'minimum' => '00:27:42'
          }
        }
      }
    end

    before do
      # rubocop:disable Style/NumericLiterals
      create(:upload_submission, :skip_record_status_change_callback,
             status: 'pending',
             consumer_name: 'Consumer1',
             metadata: {
               status: {
                 pending: { start: 1703082497 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'uploaded',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 2 },
             metadata: {
               size: 1280122,
               status: {
                 pending: { start: 1703083533, end: 1703083534 },
                 uploaded: { start: 1703083534 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'received',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 5 },
             metadata: {
               size: 833071,
               status: {
                 pending: { start: 1703083616, end: 1703083616 },
                 uploaded: { start: 1703083616, end: 1703083617 },
                 received: { start: 1703083617 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'processing',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 103 },
             metadata: {
               size: 21902120,
               status: {
                 pending: { start: 1703082646, end: 1703082647 },
                 uploaded: { start: 1703082647, end: 1703082652 },
                 received: { start: 1703082652, end: 1703083116 },
                 processing: { start: 1703083116 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'success',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 2 },
             metadata: {
               size: 511302,
               status: {
                 pending: { start: 1703082142, end: 1703082143 },
                 uploaded: { start: 1703082143, end: 1703082145 },
                 received: { start: 1703082145, end: 1703082528 },
                 processing: { start: 1703082528, end: 1703083804 },
                 success: { start: 1703083804 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'vbms',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 1 },
             metadata: {
               size: 191990,
               status: {
                 pending: { start: 1703029866, end: 1703029877 },
                 uploaded: { start: 1703029877, end: 1703029879 },
                 received: { start: 1703029879, end: 1703033591 },
                 processing: { start: 1703033591, end: 1703033591 },
                 success: { start: 1703033591, end: 1703072988 },
                 vbms: { start: 1703072988 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'error',
             consumer_name: 'Consumer1',
             uploaded_pdf: { total_pages: 2 },
             metadata: {
               size: 1221122,
               status: {
                 pending: { start: 1703080436, end: 1703080437 },
                 uploaded: { start: 1703080437, end: 1703080438 },
                 error: { start: 1703080438 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'expired',
             consumer_name: 'Consumer1',
             metadata: {})

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'success',
             consumer_name: 'Consumer2',
             uploaded_pdf: { total_pages: 2 },
             metadata: {
               size: 811009,
               status: {
                 pending: { start: 1703081972, end: 1703081973 },
                 uploaded: { start: 1703081973, end: 1703081977 },
                 received: { start: 1703081977, end: 1703083979 },
                 processing: { start: 1703083979, end: 1703083990 },
                 success: { start: 1703083990 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'vbms',
             consumer_name: 'Consumer2',
             uploaded_pdf: { total_pages: 3 },
             metadata: {
               size: 833071,
               status: {
                 pending: { start: 1703029845, end: 1703029857 },
                 uploaded: { start: 1703029857, end: 1703029859 },
                 received: { start: 1703029859, end: 1703033591 },
                 processing: { start: 1703033591, end: 1703033591 },
                 success: { start: 1703033591, end: 1703058797 },
                 vbms: { start: 1703058797 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'error',
             consumer_name: 'Consumer2',
             uploaded_pdf: { total_pages: 3 },
             metadata: {
               size: 91223,
               status: {
                 pending: { start: 1703080147, end: 1703080147 },
                 uploaded: { start: 1703080147, end: 1703080148 },
                 error: { start: 1703080148 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'error',
             consumer_name: 'Consumer2',
             uploaded_pdf: { total_pages: 2 },
             metadata: {
               size: 636333,
               status: {
                 pending: { start: 1703076523, end: 1703076524 },
                 uploaded: { start: 1703076524, end: 1703076525 },
                 error: { start: 1703076525 }
               }
             })

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'expired',
             consumer_name: 'Consumer2',
             metadata: {})

      create(:upload_submission, :skip_record_status_change_callback,
             status: 'forensics',
             consumer_name: nil) # record should be excluded
    end
    # rubocop:enable Style/NumericLiterals

    context 'when MonthlyStat record does not already exist for the month and year' do
      it 'creates a new record with the generated stats' do
        described_class.new(month:, year:).generate_and_save_stats
        expect(VBADocuments::MonthlyStat.find_by(month:, year:).stats).to eq(expected_stats_result)
      end
    end

    context 'when MonthlyStat record already exists for the month and year' do
      before { create(:monthly_stat, month:, year:, stats: {}) }

      it 'updates the existing record with the generated stats' do
        described_class.new(month:, year:).generate_and_save_stats
        expect(VBADocuments::MonthlyStat.find_by(month:, year:).stats).to eq(expected_stats_result)
      end
    end
  end
end
