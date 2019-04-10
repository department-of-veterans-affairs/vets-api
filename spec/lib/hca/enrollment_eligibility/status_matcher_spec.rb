# frozen_string_literal: true

require 'rails_helper'

describe HCA::EnrollmentEligibility::StatusMatcher do
  describe '#parse' do
    subject do
      described_class.parse(enrollment_status, ineligibility_reason)
    end
    let(:ineligibility_reason) { nil }

    [
      ['Verified', :enrolled],
      ['Not Eligible; Refused to Pay Copay', :inelig_refusedcopay],
      ['Rejected', :rejected_rightentry],
      ['Rejected;Initial Application by VAMC', :rejected_rightentry],
      ['Not Applicable', :activeduty],
      ['Deceased', :deceased],
      ['Closed Application', :closed],
      ['Pending; Means Test Required', :pending_mt],
      ['Pending; Eligibility Status is Unverified', :pending_unverified],
      ['Pending; Other', :pending_other],
      ['Pending; Purple Heart Unconfirmed', :pending_purpleheart],
      ['Cancelled/Declined', :canceled_declined],
      [nil, :none_of_the_above],
      ['Unverified', :none_of_the_above]
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
          ['24 Months', :inelig_not_enough_time],
          ['training only', :inelig_training_only],
          ['ACDUTRA', :inelig_training_only],
          ['ACDUTRa', :none_of_the_above],
          ['Other than honorable', :inelig_character_of_discharge],
          ['OTH', :inelig_character_of_discharge],
          ['non vet', :inelig_not_verified],
          ['Guard', :inelig_guard_reserve],
          ['champva', :inelig_champva],
          ['felon', :inelig_fugitivefelon],
          ['medicare', :inelig_medicare],
          ['over 65', :inelig_over65],
          ['citizen', :inelig_citizens],
          ['filipino', :inelig_filipinoscouts],
          ['disability', :rejected_sc_wrongentry],
          ['income', :rejected_inc_wrongentry]
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
