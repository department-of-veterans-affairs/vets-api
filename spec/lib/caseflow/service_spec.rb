# frozen_string_literal: true

require 'rails_helper'
require 'caseflow/service'

RSpec.describe Caseflow::Service do
  subject { described_class.new }

  let(:user) { build(:user, :loa3, ssn: '796127160') }
  let(:appeal_with_null_issue_description) do
    [
      {
        'id' => 'HLR7970',
        'issues' => [
          {
            'active' => true,
            'lastAction' => nil,
            'date' => nil,
            'description' => nil,
            'diagnosticCode' => nil
          }
        ]
      }
    ]
  end

  describe '#get_appeals' do
    context 'when one or more appeals have null issue descriptions' do
      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:warn)
      end

      it 'increments a statsd metric, logs the offending appeals, ' \
         'creates a PersonalInformationLog, and does NOT raise a JSON schema error',
         run_at: 'Wed, 20 Aug 2025 21:59:18 GMT' do
        VCR.use_cassette(
          'caseflow/appeal_with_null_issue_description',
          { match_requests_on: %i[method uri body] }
        ) do
          expect(StatsD).to receive(:increment).with(
            'api.appeals.appeals_with_null_issue_descriptions'
          )
          expect(Rails.logger).to receive(:warn).with(
            'Caseflow returned the following appeals with null issue descriptions: ' \
            "#{appeal_with_null_issue_description}"
          )
          expect(PersonalInformationLog).to receive(:create!).with(
            data: { user:, appeals: appeal_with_null_issue_description },
            error_class: 'Caseflow AppealsWithNullIssueDescriptions'
          )

          result = subject.get_appeals(user)
          expect(result.status).to eq(200)
        end
      end
    end

    context 'when an exception is raised while logging null description issues' do
      let(:user) { build(:user, :loa3, ssn: '120495723') }

      before do
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(
          Caseflow::Service
        ).to receive(
          :handle_appeals_with_null_issue_descriptions
        ).and_raise(StandardError, 'test error')
      end

      it 'logs the error',
         run_at: 'Fri, 19 Jan 2018 17:26:32 GMT' do
        VCR.use_cassette(
          'caseflow/appeals_no_alert_details_due_date',
          { match_requests_on: %i[method uri body] }
        ) do
          expect(Rails.logger).to receive(:error).with(
            'Logging null description issues for appeals failed: test error'
          )

          subject.get_appeals(user)
        end
      end
    end
  end
end
