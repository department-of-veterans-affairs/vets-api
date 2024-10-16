# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Slack::FailedSubmissionsMessenger do
  subject { described_class.new(claims, va_gov_claims, poa, itf, ews, from, to, environment) }

  let(:claims) { %w[123456 789101112] }
  let(:va_gov_claims) { %w[64738 378249] }
  let(:poa) { %w[1314151617 181920212223] }
  let(:itf) { ['24252627'] }
  let(:ews) { %w[32333435 36373839] }
  let(:from) { '2022-01-01' }
  let(:to) { '2022-01-01' }
  let(:environment) { 'production' }

  let(:link_text) do
    "<https://vagov.ddog-gov.com/logs?query='64738'&agg_m=" \
      'count&agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true&messageDisplay=inline&' \
      'refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1640803707000&to_ts=' \
      "1641062907000&live=true|64738> \n<https://vagov.ddog-gov.com/logs?query='378249'&agg_m=count&" \
      'agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true&messageDisplay=inline&' \
      'refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1640803707000&to_ts=' \
      "1641062907000&live=true|378249> \n"
  end

  describe '#build_notification_message' do
    it 'builds the notification message correctly', run_at: '2022-01-01T18:48:27Z' do
      message = subject.send(:build_notification_message)

      expected_message = "*ERRORED SUBMISSIONS* \n\n2022-01-01 - 2022-01-01 " \
                         "\nThe following submissions have encountered errors in *#{environment}*. \n\n*Disability " \
                         "Compensation Errors* \nTotal: 2 \n\n```123456 \n789101112 \n```  \n\n*Va Gov Disability " \
                         "Compensation Errors* \nTotal: 2 \n\n```<https://vagov.ddog-gov.com/logs?query='64738'&" \
                         'agg_m=count&agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true&messageDisplay=' \
                         'inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1640803707000&' \
                         "to_ts=1641062907000&live=true|64738> \n<https://vagov.ddog-gov.com/logs?query='378249'" \
                         '&agg_m=count&agg_m_source=base&agg_t=count&cols=host%2Cservice&fromUser=true' \
                         '&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream' \
                         "&from_ts=1640803707000&to_ts=1641062907000&live=true|378249> \n```  \n\n*Power of " \
                         "Attorney Errors* \nTotal: 2 \n\n```1314151617 \n181920212223 \n```  \n\n*Intent to " \
                         "File Errors* \nTotal: 1 \n\n*Evidence Waiver Errors* \nTotal: 2 " \
                         "\n\n```32333435 \n36373839 \n```  \n\n"

      expect(message).to include("#{claims.count} \n")
      expect(message).to include("123456 \n789101112 \n")
      expect(message).to include("#{va_gov_claims.count} \n")
      expect(message).to include(link_text)
      expect(message).to include("#{poa.count} \n")
      expect(message).to include("1314151617 \n181920212223 \n")
      expect(message).to include("#{itf.count} \n")
      expect(message).not_to include("24252627 \n")
      expect(message).to include("#{ews.count} \n")
      expect(message).to include("32333435 \n36373839 \n")

      expect(message).to eq(expected_message)
    end
  end
end
