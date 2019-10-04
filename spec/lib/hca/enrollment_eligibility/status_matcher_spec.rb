# frozen_string_literal: true

require 'rails_helper'

describe HCA::EnrollmentEligibility::StatusMatcher do
  describe '#parse' do
    subject do
      described_class.parse(enrollment_status, ineligibility_reason)
    end

    let(:ineligibility_reason) { nil }

    [
      ['Verified', Notification::ENROLLED],
      ['Not Eligible; Refused to Pay Copay', Notification::INELIG_REFUSEDCOPAY],
      ['Rejected', Notification::REJECTED_RIGHTENTRY],
      ['Rejected;Initial Application by VAMC', Notification::REJECTED_RIGHTENTRY],
      ['Not Applicable', Notification::ACTIVEDUTY],
      ['Deceased', Notification::DECEASED],
      ['Closed Application', Notification::CLOSED],
      ['Pending; Means Test Required', Notification::PENDING_MT],
      ['Pending; Eligibility Status is Unverified', Notification::PENDING_UNVERIFIED],
      ['Pending; Other', Notification::PENDING_OTHER],
      ['Pending; Purple Heart Unconfirmed', Notification::PENDING_PURPLEHEART],
      ['Cancelled/Declined', Notification::CANCELED_DECLINED],
      [nil, Notification::NONE_OF_THE_ABOVE],
      ['Unverified', Notification::NONE_OF_THE_ABOVE]
    ].each do |test_data|
      context "when enrollment status is #{test_data[0]}" do
        let(:enrollment_status) { test_data[0] }

        it "returns #{test_data[1]}" do
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
          ['24 Months', Notification::INELIG_NOT_ENOUGH_TIME],
          ['training only', Notification::INELIG_TRAINING_ONLY],
          ['ACDUTRA', Notification::INELIG_TRAINING_ONLY],
          ['ACDUTRa', Notification::INELIG_OTHER],
          ['Other than honorable', Notification::INELIG_CHARACTER_OF_DISCHARGE],
          ['OTH', Notification::INELIG_CHARACTER_OF_DISCHARGE],
          ['non vet', Notification::INELIG_NOT_VERIFIED],
          ['Guard', Notification::INELIG_GUARD_RESERVE],
          ['champva', Notification::INELIG_CHAMPVA],
          ['felon', Notification::INELIG_FUGITIVEFELON],
          ['medicare', Notification::INELIG_MEDICARE],
          ['over 65', Notification::INELIG_OVER65],
          ['citizen', Notification::INELIG_CITIZENS],
          ['filipino', Notification::INELIG_FILIPINOSCOUTS],
          ['disability', Notification::REJECTED_SC_WRONGENTRY],
          ['income', Notification::REJECTED_INC_WRONGENTRY]
        ].each do |test_data|
          context "when text includes #{test_data[0]}" do
            let(:ineligibility_reason) { "abc #{test_data[0]}." }

            it "returns #{test_data[1]}" do
              expect(subject).to eq(test_data[1])
            end
          end
        end
      end
    end
  end
end
