# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Slack::FailedSubmissionsMessenger do
  subject { described_class.new(claims, poa, itf, ews, from, to) }

  let(:claims) { %w[123456 789101112] }
  let(:poa) { %w[1314151617 181920212223] }
  let(:itf) { ['24252627'] }
  let(:ews) { %w[32333435 36373839] }
  let(:from) { '2022-01-01' }
  let(:to) { '2022-01-31' }

  describe '#build_notification_message' do
    it 'builds the notification message correctly' do
      message = subject.send(:build_notification_message)

      expected_message = "*ERRORED SUBMISSIONS* \n\n2022-01-01 - 2022-01-31 " \
                         "\nThe following submissions have encountered errors in **. \n\n*Disability " \
                         "Compensation Errors* \nTotal: 2 \n```123456 \n789101112 \n```  \n\n*Power of " \
                         "Attorney Errors* \nTotal: 2 \n```1314151617 \n181920212223 \n```  \n\n*Intent to " \
                         "File Errors* \nTotal: 1 \n```24252627 \n```  \n\n*Evidence Waiver Errors* \nTotal: 2 " \
                         "\n```32333435 \n36373839 \n```  \n\n"

      expect(message).to include("#{claims.count} \n")
      expect(message).to include("#{poa.count} \n")
      expect(message).to include("#{itf.count} \n")
      expect(message).to include("#{ews.count} \n")

      expect(message).to eq(expected_message)
    end
  end
end
