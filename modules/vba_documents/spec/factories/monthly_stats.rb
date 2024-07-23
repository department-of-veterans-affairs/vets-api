# frozen_string_literal: true

FactoryBot.define do
  factory :monthly_stat, class: 'VBADocuments::MonthlyStat' do
    month { 11 }
    year { 2023 }
    stats {
      {
        'summary_stats' => {
          'total' => 137_038,
          'vbms_count' => 133_547,
          'error_percent' => 0.01,
          'errored_count' => 874,
          'expired_count' => 1678,
          'success_count' => 939,
          'processing_count' => 0
        },
        'consumer_stats' => [
          {
            'total' => 1036,
            'vbms_count' => 1009,
            'consumer_name' => 'Consumer1',
            'error_percent' => 0.01,
            'errored_count' => 7,
            'expired_count' => 6,
            'success_count' => 14,
            'processing_count' => 0
          },
          {
            'total' => 17_942,
            'vbms_count' => 17_638,
            'consumer_name' => 'Consumer2',
            'error_percent' => 0.01,
            'errored_count' => 120,
            'expired_count' => 60,
            'success_count' => 124,
            'processing_count' => 0
          },
          {
            'total' => 1426,
            'vbms_count' => 1417,
            'consumer_name' => 'Consumer3',
            'error_percent' => 0.0,
            'errored_count' => 2,
            'expired_count' => 0,
            'success_count' => 7,
            'processing_count' => 0
          },
          {
            'total' => 123,
            'vbms_count' => 119,
            'consumer_name' => 'Consumer4',
            'error_percent' => 0.02,
            'errored_count' => 3,
            'expired_count' => 1,
            'success_count' => 0,
            'processing_count' => 0
          },
          {
            'total' => 1609,
            'vbms_count' => 1587,
            'consumer_name' => 'Consumer5',
            'error_percent' => 0.0,
            'errored_count' => 2,
            'expired_count' => 15,
            'success_count' => 5,
            'processing_count' => 0
          },
          {
            'total' => 6,
            'vbms_count' => 6,
            'consumer_name' => 'Consumer6',
            'error_percent' => 0.0,
            'errored_count' => 0,
            'expired_count' => 0,
            'success_count' => 0,
            'processing_count' => 0
          },
          {
            'total' => 377,
            'vbms_count' => 370,
            'consumer_name' => 'Consumer7',
            'error_percent' => 0.02,
            'errored_count' => 7,
            'expired_count' => 0,
            'success_count' => 0,
            'processing_count' => 0
          },
          {
            'total' => 44_648,
            'vbms_count' => 44_389,
            'consumer_name' => 'Consumer8',
            'error_percent' => 0.0,
            'errored_count' => 90,
            'expired_count' => 5,
            'success_count' => 164,
            'processing_count' => 0
          },
          {
            'total' => 40_098,
            'vbms_count' => 39_095,
            'consumer_name' => 'Consumer9',
            'error_percent' => 0.01,
            'errored_count' => 245,
            'expired_count' => 353,
            'success_count' => 405,
            'processing_count' => 0
          },
          {
            'total' => 1220,
            'vbms_count' => 1165,
            'consumer_name' => 'Consumer10',
            'error_percent' => 0.01,
            'errored_count' => 18,
            'expired_count' => 17,
            'success_count' => 20,
            'processing_count' => 0
          },
          {
            'total' => 116,
            'vbms_count' => 113,
            'consumer_name' => 'Consumer11',
            'error_percent' => 0.0,
            'errored_count' => 0,
            'expired_count' => 0,
            'success_count' => 3,
            'processing_count' => 0
          },
          {
            'total' => 315,
            'vbms_count' => 239,
            'consumer_name' => 'Consumer12',
            'error_percent' => 0.0,
            'errored_count' => 1,
            'expired_count' => 1,
            'success_count' => 74,
            'processing_count' => 0
          },
          {
            'total' => 17_394,
            'vbms_count' => 17_338,
            'consumer_name' => 'Consumer13',
            'error_percent' => 0.0,
            'errored_count' => 28,
            'expired_count' => 6,
            'success_count' => 22,
            'processing_count' => 0
          },
          {
            'total' => 2359,
            'vbms_count' => 2247,
            'consumer_name' => 'Consumer14',
            'error_percent' => 0.01,
            'errored_count' => 25,
            'expired_count' => 7,
            'success_count' => 80,
            'processing_count' => 0
          },
          {
            'total' => 2662,
            'vbms_count' => 2617,
            'consumer_name' => 'Consumer15',
            'error_percent' => 0.01,
            'errored_count' => 17,
            'expired_count' => 11,
            'success_count' => 17,
            'processing_count' => 0
          },
          {
            'total' => 5707,
            'vbms_count' => 4198,
            'consumer_name' => 'Consumer16',
            'error_percent' => 0.05,
            'errored_count' => 309,
            'expired_count' => 1196,
            'success_count' => 4,
            'processing_count' => 0
          }
        ],
        'page_count_stats' => {
          'mode' => 2,
          'total' => 3_094_220,
          'median' => 5.0,
          'average' => 22.9,
          'maximum' => 11_529
        },
        'upload_size_in_mb_stats' => {
          'mode' => 0.32,
          'median' => 1.46,
          'average' => 3.88,
          'maximum' => 1005.18
        },
        'status_elapsed_time_stats' => {
          'pending' => {
            'total' => 137_038,
            'median' => '00:00:04',
            'average' => '00:00:21',
            'maximum' => '00:23:56',
            'minimum' => '00:00:00'
          },
          'success' => {
            'total' => 133_558,
            'median' => '15:57:32',
            'average' => '24:15:43',
            'maximum' => '633:56:25',
            'minimum' => '00:58:44'
          },
          'received' => {
            'total' => 134_586,
            'median' => '00:45:48',
            'average' => '01:06:00',
            'maximum' => '109:28:29',
            'minimum' => '00:02:37'
          },
          'uploaded' => {
            'total' => 135_360,
            'median' => '00:00:04',
            'average' => '00:36:41',
            'maximum' => '93:27:43',
            'minimum' => '00:00:00'
          },
          'processing' => {
            'total' => 129_887,
            'median' => '01:59:36',
            'average' => '03:12:07',
            'maximum' => '99:54:58',
            'minimum' => '00:02:50'
          },
          'pending_to_vbms' => {
            'total' => 133_547,
            'average' => '29:01:11',
            'maximum' => '636:13:13',
            'minimum' => '00:59:58'
          },
          'success_to_vbms' => {
            'total' => 133_499,
            'average' => '24:13:41',
            'maximum' => '633:56:25',
            'minimum' => '00:58:44'
          },
          'pending_to_error' => {
            'total' => 877,
            'average' => '07:25:05',
            'maximum' => '187:26:41',
            'minimum' => '00:00:01'
          },
          'pending_to_success' => {
            'total' => 134_497,
            'average' => '04:48:31',
            'maximum' => '110:29:11',
            'minimum' => '00:17:10'
          }
        }
      }
    }
  end
end
