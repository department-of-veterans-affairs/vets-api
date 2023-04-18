# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::PreCacheClaimsAndAppealsJob, type: :job do
  before do
    Sidekiq::Worker.clear_all
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  describe '.perform_async' do
    let(:user) { create(:user, :loa3) }

    it 'caches the expected claims and appeals' do
      VCR.use_cassette('claims/claims') do
        VCR.use_cassette('appeals/appeals') do
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
            {
              id: 'SC1678',
              type: 'appeal',
              subtype: 'supplementalClaim',
              completed: false,
              date_filed: '2020-09-23',
              updated_at: '2020-09-23',
              display_title: 'supplemental claim for disability compensation',
              decision_letter_sent: false
            }
          )
        end
      end
    end

    it 'logs a warning with details when fetch fails' do
      VCR.use_cassette('claims/claims_with_errors') do
        VCR.use_cassette('appeals/appeals') do
          expect(Rails.logger).to receive(:warn).with(
            'mobile claims pre-cache set failed',
            { errors: [{ error_details: [{ 'key' => 'EVSS_7022',
                                           'severity' => 'ERROR',
                                           'text' =>
                     "Please define your custom text for this error in claims-webparts/ErrorCodeMessages.properties. \
[Unique ID: 1522946240935]" }],
                         service: 'claims' }],
              user_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
          )
          subject.perform(user.uuid)
          expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
        end
      end
    end

    context 'with an IAM user' do
      let(:user) { FactoryBot.build(:iam_user) }

      before { iam_sign_in(user) }

      it 'caches the expected claims and appeals' do
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/appeals') do
            expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
            subject.perform(user.uuid)
            expect(Mobile::V0::ClaimOverview.get_cached(user).first.to_h).to eq(
              {
                id: 'SC1678',
                type: 'appeal',
                subtype: 'supplementalClaim',
                completed: false,
                date_filed: '2020-09-23',
                updated_at: '2020-09-23',
                display_title: 'supplemental claim for disability compensation',
                decision_letter_sent: false
              }
            )
          end
        end
      end
    end

    context 'when user is not found' do
      it 'caches the expected claims and appeals' do
        expect do
          subject.perform('iamtheuuidnow')
        end.to raise_error(described_class::MissingUserError, 'iamtheuuidnow')
        expect(Mobile::V0::ClaimOverview.get_cached(user)).to be_nil
      end
    end
  end
end
