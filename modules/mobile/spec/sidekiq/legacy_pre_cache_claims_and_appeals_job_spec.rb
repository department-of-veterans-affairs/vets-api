# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::PreCacheClaimsAndAppealsJob, type: :job do
  before do
    Sidekiq::Job.clear_all
  end

  before(:all) do
    Flipper.disable(:mobile_lighthouse_claims)
  end

  after do
    Flipper.enable(:mobile_lighthouse_claims)
  end

  describe '.perform_async' do
    let(:user) { create(:user, :loa3) }

    it 'caches the expected claims and appeals' do
      VCR.use_cassette('mobile/claims/claims') do
        VCR.use_cassette('mobile/appeals/appeals') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)

          expect(Mobile::V0::ClaimOverview.get_cached(user).count).to eq(148)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            {
              id: 'SC1678',
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
              claim_type_code: nil
            }
          )
        end
      end
    end

    context 'when claims or appeals is not authorized' do
      it 'caches the expected claims' do
        allow_any_instance_of(AppealsPolicy).to receive(:access?).and_return(false)

        VCR.use_cassette('mobile/claims/claims') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user).count).to eq(143)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            { id: '600118851',
              type: 'claim',
              subtype: 'Compensation',
              completed: false,
              date_filed: '2017-12-08',
              updated_at: '2017-12-08',
              display_title: 'Compensation',
              decision_letter_sent: false,
              phase: nil,
              documents_needed: nil,
              development_letter_sent: nil,
              claim_type_code: nil }
          )
        end
      end

      it 'caches the expected appeals' do
        allow_any_instance_of(EVSSPolicy).to receive(:access?).and_return(false)

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

    it 'does not cache when received non authorization error' do
      VCR.use_cassette('mobile/claims/claims_with_errors') do
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
