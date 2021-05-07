# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe Mobile::V0::PreCacheClaimsAndAppealsJob, type: :job do
  before do
    iam_sign_in
    Sidekiq::Worker.clear_all
  end

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:user) { FactoryBot.build(:iam_user) }

  describe '.perform_async' do
    context 'with no errors' do
      it 'caches the expected claims and appeals' do
        VCR.use_cassette('claims/claims') do
          VCR.use_cassette('appeals/appeals') do
            expect(Mobile::V0::ClaimOverview.get_cached(user.uuid)).to be_nil
            subject.perform(user.uuid)
            expect(Mobile::V0::ClaimOverview.get_cached(user.uuid).first.to_h).to eq(
              {
                id: 'SC1678',
                type: 'appeal',
                subtype: 'supplementalClaim',
                completed: false,
                date_filed: '2020-09-23',
                updated_at: '2020-09-23T00:00:00+00:00'
              }
            )
          end
        end
      end
    end

    context 'with any errors' do
      it 'does not cache the appointments' do
        VCR.use_cassette('claims/claims_with_errors') do
          VCR.use_cassette('appeals/appeals') do
            expect(Mobile::V0::ClaimOverview.get_cached(user.uuid)).to be_nil
            subject.perform(user.uuid)
            expect(Mobile::V0::ClaimOverview.get_cached(user.uuid)).to be_nil
          end
        end
      end
    end
  end
end
