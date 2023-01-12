# frozen_string_literal: true

require 'rails_helper'
require 'hca/enrollment_eligibility/status_matcher'

describe HCA::EnrollmentEligibility::StatusMatcher do
  describe '#parse' do
    subject do
      described_class.parse(enrollment_status, ineligibility_reason)
    end

    let(:ineligibility_reason) { nil }

    [
      ['Verified', HCA::EnrollmentEligibility::Constants::ENROLLED],
      ['Not Eligible; Refused to Pay Copay', HCA::EnrollmentEligibility::Constants::INELIG_REFUSEDCOPAY],
      ['Rejected', HCA::EnrollmentEligibility::Constants::REJECTED_RIGHTENTRY],
      ['Rejected;Initial Application by VAMC', HCA::EnrollmentEligibility::Constants::REJECTED_RIGHTENTRY],
      ['Not Applicable', HCA::EnrollmentEligibility::Constants::ACTIVEDUTY],
      ['Deceased', HCA::EnrollmentEligibility::Constants::DECEASED],
      ['Closed Application', HCA::EnrollmentEligibility::Constants::CLOSED],
      ['Pending; Means Test Required', HCA::EnrollmentEligibility::Constants::PENDING_MT],
      ['Pending; Eligibility Status is Unverified', HCA::EnrollmentEligibility::Constants::PENDING_UNVERIFIED],
      ['Pending; Other', HCA::EnrollmentEligibility::Constants::PENDING_OTHER],
      ['Pending; Purple Heart Unconfirmed', HCA::EnrollmentEligibility::Constants::PENDING_PURPLEHEART],
      ['Cancelled/Declined', HCA::EnrollmentEligibility::Constants::CANCELED_DECLINED],
      [nil, HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE],
      ['Unverified', HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE]
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
          ['24 Months', HCA::EnrollmentEligibility::Constants::INELIG_NOT_ENOUGH_TIME],
          ['training only', HCA::EnrollmentEligibility::Constants::INELIG_TRAINING_ONLY],
          ['ACDUTRA', HCA::EnrollmentEligibility::Constants::INELIG_TRAINING_ONLY],
          ['ACDUTRa', HCA::EnrollmentEligibility::Constants::INELIG_OTHER],
          ['Other than honorable', HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE],
          ['OTH', HCA::EnrollmentEligibility::Constants::INELIG_CHARACTER_OF_DISCHARGE],
          ['non vet', HCA::EnrollmentEligibility::Constants::INELIG_NOT_VERIFIED],
          ['Guard', HCA::EnrollmentEligibility::Constants::INELIG_GUARD_RESERVE],
          ['champva', HCA::EnrollmentEligibility::Constants::INELIG_CHAMPVA],
          ['felon', HCA::EnrollmentEligibility::Constants::INELIG_FUGITIVEFELON],
          ['medicare', HCA::EnrollmentEligibility::Constants::INELIG_MEDICARE],
          ['over 65', HCA::EnrollmentEligibility::Constants::INELIG_OVER65],
          ['citizen', HCA::EnrollmentEligibility::Constants::INELIG_CITIZENS],
          ['filipino', HCA::EnrollmentEligibility::Constants::INELIG_FILIPINOSCOUTS],
          ['disability', HCA::EnrollmentEligibility::Constants::REJECTED_SC_WRONGENTRY],
          ['income', HCA::EnrollmentEligibility::Constants::REJECTED_INC_WRONGENTRY]
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
