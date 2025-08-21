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
         'creates a PersonalInformationLog, and raises a JSON schema error',
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

          expect { subject.get_appeals(user) }.to raise_error(JSON::Schema::ValidationError)
        end
      end
    end
  end
end
