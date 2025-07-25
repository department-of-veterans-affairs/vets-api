# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'
require 'lighthouse/benefits_claims/configuration'
require 'lighthouse/benefits_claims/service'

RSpec.describe Mobile::V0::PreCacheClaimsAndAppealsJob, type: :job do
  before do
    Sidekiq::Job.clear_all
    token = 'abcdefghijklmnop'
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
  end

  describe '.perform_async' do
    let(:user) { sis_user(icn: '1008596379V859838') }

    it 'caches the expected claims and appeals' do
      VCR.use_cassette('mobile/lighthouse_claims/index/200_response') do
        VCR.use_cassette('mobile/appeals/appeals') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user).count).to eq(11)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            {
              id: '600383363',
              type: 'claim',
              subtype: 'Compensation',
              completed: false,
              date_filed: '2022-09-27',
              updated_at: '2022-09-30',
              display_title: 'Compensation',
              decision_letter_sent: false,
              phase: 4,
              documents_needed: false,
              development_letter_sent: true,
              claim_type_code: '400PREDSCHRG'
            }
          )
        end
      end
    end

    context 'when claims or appeals is not authorized' do
      it 'caches the expected claims' do
        allow_any_instance_of(AppealsPolicy).to receive(:access?).and_return(false)

        VCR.use_cassette('mobile/lighthouse_claims/index/200_response') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user).count).to eq(6)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            { id: '600383363',
              type: 'claim',
              subtype: 'Compensation',
              completed: false,
              date_filed: '2022-09-27',
              updated_at: '2022-09-30',
              display_title: 'Compensation',
              decision_letter_sent: false,
              phase: 4,
              documents_needed: false,
              development_letter_sent: true,
              claim_type_code: '400PREDSCHRG' }
          )
        end
      end

      it 'caches the expected appeals' do
        allow_any_instance_of(LighthousePolicy).to receive(:access?).and_return(false)

        VCR.use_cassette('mobile/appeals/appeals') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user).count).to eq(5)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            { id: 'SC1678',
              type: 'appeal',
              subtype: 'supplementalClaim',
              completed: false,
              date_filed: '2020-09-23',
              updated_at: '2020-09-23',
              display_title: 'supplemental claim for disability compensation',
              decision_letter_sent: false,
              phase: nil,
              documents_needed: nil,
              development_letter_sent: nil,
              claim_type_code: nil }
          )
        end
      end
    end

    it 'does not cache when a non authorization error is present' do
      VCR.use_cassette('mobile/lighthouse_claims/index/404_response') do
        VCR.use_cassette('mobile/appeals/appeals') do
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
        end
      end
    end

    context 'when user is not found' do
      it 'caches the expected claims and appeals' do
        expect(Rails.logger).to receive(:warn).with(
          'mobile claims pre-cache job failed', user_uuid: 'iamtheuuidnow',
                                                errors: 'iamtheuuidnow',
                                                type: 'Mobile::V0::PreCacheClaimsAndAppealsJob::MissingUserError'
        )
        expect do
          subject.perform('iamtheuuidnow')
        end.not_to raise_error
        expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
      end
    end
  end
end
