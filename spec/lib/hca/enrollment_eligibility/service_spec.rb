# frozen_string_literal: true

require 'rails_helper'
require 'hca/enrollment_eligibility/service'

describe HCA::EnrollmentEligibility::Service do
  describe '#lookup_user' do
    context 'with a user that has an ineligibility_reason' do
      it 'gets the ineligibility_reason', run_at: 'Wed, 13 Feb 2019 09:20:47 GMT' do
        VCR.use_cassette(
          'hca/ee/lookup_user_ineligibility_reason',
          VCR::MATCH_EVERYTHING.merge(erb: true)
        ) do
          expect(
            described_class.new.lookup_user('0000001013030524V532318000000')
          ).to eq(
            enrollment_status: 'Not Eligible; Ineligible Date',
            application_date: '2018-01-24T00:00:00.000-06:00',
            enrollment_date: nil,
            preferred_facility: '987 - CHEY6',
            ineligibility_reason: 'for testing',
            effective_date: '2019-01-25T09:04:04.000-06:00',
            primary_eligibility: 'HUMANITARIAN EMERGENCY',
            veteran: 'false',
            priority_group: nil
          )
        end
      end
    end

    it 'lookups the user through the hca ee api', run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
      VCR.use_cassette(
        'hca/ee/lookup_user',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect(
          described_class.new.lookup_user('1013032368V065534')
        ).to eq(
          enrollment_status: 'Verified',
          application_date: '2018-12-27T00:00:00.000-06:00',
          enrollment_date: '2018-12-27T17:15:39.000-06:00',
          preferred_facility: '988 - DAYT20',
          ineligibility_reason: nil,
          effective_date: '2019-01-02T21:58:55.000-06:00',
          primary_eligibility: 'SC LESS THAN 50%',
          veteran: 'true',
          priority_group: 'Group 3'
        )
      end
    end
  end
end
