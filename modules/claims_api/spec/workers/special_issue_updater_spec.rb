# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SpecialIssueUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:contention_id) { 'contention-id-here' }
  let(:special_issues) { %w[ALS PTSD/2] }

  it 'submits successfully' do
    expect do
      subject.perform_async(user, contention_id, special_issues)
    end.to change(subject.jobs, :size).by(1)
  end

  context 'when no matching claim is found' do
    let(:claims) { { benefit_claims: [] } }

    it 'job fails and retries later' do
      expect_any_instance_of(BGS::ContentionService).to receive(:find_contentions_by_ptcpnt_id)
        .and_return(claims)

      expect {
        subject.new.perform(user, contention_id, special_issues)
      }.to raise_error(StandardError)
    end
  end

  context 'when a matching claim is found' do
    context 'when no matching contention is found' do
      it 'job fails and retries later' do
        skip '##TODO'
      end
    end

    context 'when a matching contention is found' do
      context 'when contention does not have existing special issues' do
        it 'all special issues provided are appended to payload' do
          skip '##TODO'
        end
      end

      context 'when contention does have existing special issues' do
        context 'when one or more special issue provided is new' do
          it 'new special issues provided are added while preserving existing special issues' do
            skip '##TODO'
          end
        end

        context 'when none of the special issues provided is new' do
          it 'existing special issues are left unchanged' do
            skip '##TODO'
          end
        end
      end
    end
  end
end
