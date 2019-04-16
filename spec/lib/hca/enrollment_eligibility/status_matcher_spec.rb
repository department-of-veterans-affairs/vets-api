# frozen_string_literal: true

require 'rails_helper'

describe HCA::EnrollmentEligibility::StatusMatcher do
  describe '#parse' do
    STATUS = HCA::EnrollmentEligibility::ParsedStatuses

    subject do
      described_class.parse(enrollment_status, ineligibility_reason)
    end
    let(:ineligibility_reason) { nil }

    [
      ['Verified', STATUS::ENROLLED],
      ['Not Eligible; Refused to Pay Copay', STATUS::INELIG_REFUSEDCOPAY],
      ['Rejected', STATUS::REJECTED_RIGHTENTRY],
      ['Rejected;Initial Application by VAMC', STATUS::REJECTED_RIGHTENTRY],
      ['Not Applicable', STATUS::ACTIVEDUTY],
      ['Deceased', STATUS::DECEASED],
      ['Closed Application', STATUS::CLOSED],
      ['Pending; Means Test Required', STATUS::PENDING_MT],
      ['Pending; Eligibility Status is Unverified', STATUS::PENDING_UNVERIFIED],
      ['Pending; Other', STATUS::PENDING_OTHER],
      ['Pending; Purple Heart Unconfirmed', STATUS::PENDING_PURPLEHEART],
      ['Cancelled/Declined', STATUS::CANCELED_DECLINED],
      [nil, STATUS::NONE],
      ['Unverified', STATUS::NONE]
    ].each do |test_data|
      context "when enrollment status is #{test_data[0]}" do
        let(:enrollment_status) { test_data[0] }

        it "should return #{test_data[1]}" do
          expect(subject).to eq(test_data[1])
        end
      end
    end

    [
      'Not Eligible',
      'Not Eligible; Ineligible Date'
    ].each do |enrollment_status|
      context "when enrollment_status is #{enrollment_status}" do
        let(:enrollment_status) { enrollment_status }

        [
          ['24 Months', STATUS::INELIG_NOT_ENOUGH_TIME],
          ['training only', STATUS::INELIG_TRAINING_ONLY],
          ['ACDUTRA', STATUS::INELIG_TRAINING_ONLY],
          ['ACDUTRa', STATUS::NONE],
          ['Other than honorable', STATUS::INELIG_CHARACTER_OF_DISCHARGE],
          ['OTH', STATUS::INELIG_CHARACTER_OF_DISCHARGE],
          ['non vet', STATUS::INELIG_NOT_VERIFIED],
          ['Guard', STATUS::INELIG_GUARD_RESERVE],
          ['champva', STATUS::INELIG_CHAMPVA],
          ['felon', STATUS::INELIG_FUGITIVEFELON],
          ['medicare', STATUS::INELIG_MEDICARE],
          ['over 65', STATUS::INELIG_OVER65],
          ['citizen', STATUS::INELIG_CITIZENS],
          ['filipino', STATUS::INELIG_FILIPINOSCOUTS],
          ['disability', STATUS::REJECTED_SC_WRONGENTRY],
          ['income', STATUS::REJECTED_INC_WRONGENTRY]
        ].each do |test_data|
          context "when text includes #{test_data[0]}" do
            let(:ineligibility_reason) { "abc #{test_data[0]}." }

            it "should return #{test_data[1]}" do
              expect(subject).to eq(test_data[1])
            end
          end
        end
      end
    end
  end
end
