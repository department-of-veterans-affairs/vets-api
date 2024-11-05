# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SpecialIssueUpdater, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
  end

  let(:user) do
    user_mock = FactoryBot.create(:evss_user, :loa3)
    {
      'ssn' => user_mock.ssn
    }
  end
  let(:contention_id) { { claim_id: '123', code: '200', name: 'contention-name-here' } }
  let(:claim_record) { create(:auto_established_claim, :special_issues) }
  let(:special_issues) { claim_record.special_issues }

  it 'submits successfully' do
    expect do
      subject.perform_async(contention_id, special_issues, claim_record.id)
    end.to change(subject.jobs, :size).by(1)
  end

  context 'when no matching claim is found' do
    let(:claims) { { benefit_claims: [] } }

    it 'job fails and retries later' do
      expect_any_instance_of(BGS::ContentionService).to receive(:find_contentions_by_ptcpnt_id)
        .and_return(claims)

      expect do
        subject.new.perform(contention_id, special_issues, claim_record.id)
      end.to raise_error(StandardError)
    end
  end

  context 'when a matching claim is found' do
    before do
      expect_any_instance_of(BGS::ContentionService).to receive(:find_contentions_by_ptcpnt_id)
        .and_return(claims)
    end

    context 'when no matching contention is found' do
      let(:claims) do
        {
          benefit_claims: [
            {
              contentions: [
                { clm_id: '321', clsfcn_id: '333', clmnt_txt: 'different-name-here' }
              ]
            }
          ]
        }
      end

      it 'job fails and retries later' do
        expect do
          subject.new.perform(contention_id, special_issues, claim_record.id)
        end.to raise_error(StandardError)
      end
    end

    context 'when a matching contention is found' do
      context 'when contention does not have existing special issues' do
        context 'when multiple contentions exist for claim' do
          let(:claim_id) { '600200323' }
          let(:claim) do
            {
              jrn_dt: '2020-08-17T10:44:43-05:00',
              bnft_clm_tc: '130DPNEBNADJ',
              bnft_clm_tn: 'eBenefits Dependency Adjustment',
              claim_rcvd_dt: '2020-08-17T00:00:00-05:00',
              clm_id: claim_id,
              contentions: [
                {
                  clm_id: contention_id[:claim_id],
                  cntntn_id: '999111',
                  clsfcn_id: contention_id[:code],
                  clmnt_txt: contention_id[:name]
                },
                {
                  clm_id: '321',
                  cntntn_id: '123456',
                  clsfcn_id: '333',
                  clmnt_txt: 'different-name-here'
                }
              ],
              lc_stt_rsn_tc: 'OPEN',
              lc_stt_rsn_tn: 'Open',
              lctn_id: '322',
              non_med_clm_desc: 'eBenefits Dependency Adjustment',
              prirty: '0',
              ptcpnt_id_clmnt: '600036156',
              ptcpnt_id_vet: '600036156',
              ptcpnt_suspns_id: '600276939',
              soj_lctn_id: '347'
            }
          end
          let(:claims) { { benefit_claims: [claim] } }

          it 'all special issues provided are appended to payload' do
            expected_claim_options = claim.dup
            special_issues_payload = special_issues.map { |si| { spis_tc: si } }
            expected_claim_options[:contentions] = [
              { clm_id: claim_id, cntntn_id: '999111', special_issues: special_issues_payload },
              { clm_id: claim_id, cntntn_id: '123456', special_issues: [] }
            ]
            expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions).with(expected_claim_options)

            subject.new.perform(contention_id, special_issues, claim_record.id)
          end

          it 'stores bgs exceptions correctly' do
            expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions)
              .and_raise(BGS::ShareError.new('failed', 500))

            subject.new.perform(contention_id, special_issues, claim_record.id)
            expect(ClaimsApi::AutoEstablishedClaim.find(claim_record.id).bgs_special_issue_responses.count).to eq(1)
          end
        end

        context 'when a single contention exists for claim' do
          let(:claim_id) { '600200323' }
          let(:claim) do
            {
              jrn_dt: '2020-08-17T10:44:43-05:00',
              bnft_clm_tc: '130DPNEBNADJ',
              bnft_clm_tn: 'eBenefits Dependency Adjustment',
              claim_rcvd_dt: '2020-08-17T00:00:00-05:00',
              clm_id: claim_id,
              contentions: {
                clm_id: contention_id[:claim_id],
                cntntn_id: '999111',
                clsfcn_id: contention_id[:code],
                clmnt_txt: contention_id[:name]
              },
              lc_stt_rsn_tc: 'OPEN',
              lc_stt_rsn_tn: 'Open',
              lctn_id: '322',
              non_med_clm_desc: 'eBenefits Dependency Adjustment',
              prirty: '0',
              ptcpnt_id_clmnt: '600036156',
              ptcpnt_id_vet: '600036156',
              ptcpnt_suspns_id: '600276939',
              soj_lctn_id: '347'
            }
          end
          let(:claims) { { benefit_claims: [claim] } }

          it 'all special issues provided are appended to payload' do
            expected_claim_options = claim.dup
            special_issues_payload = special_issues.map { |si| { spis_tc: si } }
            expected_claim_options[:contentions] = [
              { clm_id: claim_id, cntntn_id: '999111', special_issues: special_issues_payload }
            ]
            expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions).with(expected_claim_options)

            subject.new.perform(contention_id, special_issues, claim_record.id)
          end
        end
      end

      context 'when contention does have existing special issues' do
        context 'when one or more special issue provided is new' do
          let(:claim_id) { '600200323' }
          let(:claim) do
            {
              jrn_dt: '2020-08-17T10:44:43-05:00',
              bnft_clm_tc: '130DPNEBNADJ',
              bnft_clm_tn: 'eBenefits Dependency Adjustment',
              claim_rcvd_dt: '2020-08-17T00:00:00-05:00',
              clm_id: claim_id,
              contentions: [
                {
                  clm_id: contention_id[:claim_id],
                  cntntn_id: '999111',
                  clsfcn_id: contention_id[:code],
                  clmnt_txt: contention_id[:name],
                  special_issues: [{ spis_tc: 'something-else' }, { spis_tc: 'ALS' }]
                }
              ],
              lc_stt_rsn_tc: 'OPEN',
              lc_stt_rsn_tn: 'Open',
              lctn_id: '322',
              non_med_clm_desc: 'eBenefits Dependency Adjustment',
              prirty: '0',
              ptcpnt_id_clmnt: '600036156',
              ptcpnt_id_vet: '600036156',
              ptcpnt_suspns_id: '600276939',
              soj_lctn_id: '347'
            }
          end
          let(:claims) { { benefit_claims: [claim] } }

          it 'new special issues provided are added while preserving existing special issues' do
            expected_claim_options = claim.dup
            special_issues_payload =
              [{ spis_tc: { 'code' => 9999,
                            'name' => 'PTSD (post traumatic stress disorder)',
                            'special_issues' => ['FDC', 'PTSD/2'] } },
               { spis_tc: 'something-else' },
               { spis_tc: 'ALS' }]
            expected_claim_options[:contentions] = [
              { clm_id: claim_id, cntntn_id: '999111', special_issues: special_issues_payload }
            ]
            expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions).with(expected_claim_options)

            subject.new.perform(contention_id, special_issues, claim_record.id)
          end
        end

        context 'when none of the special issues provided is new' do
          let(:claim_id) { '600200323' }
          let(:claim) do
            {
              jrn_dt: '2020-08-17T10:44:43-05:00',
              bnft_clm_tc: '130DPNEBNADJ',
              bnft_clm_tn: 'eBenefits Dependency Adjustment',
              claim_rcvd_dt: '2020-08-17T00:00:00-05:00',
              clm_id: claim_id,
              contentions: [
                {
                  clm_id: contention_id[:claim_id],
                  cntntn_id: '999111',
                  clsfcn_id: contention_id[:code],
                  clmnt_txt: contention_id[:name],
                  special_issues: (special_issues.map { |si| { spis_tc: si } })
                }
              ],
              lc_stt_rsn_tc: 'OPEN',
              lc_stt_rsn_tn: 'Open',
              lctn_id: '322',
              non_med_clm_desc: 'eBenefits Dependency Adjustment',
              prirty: '0',
              ptcpnt_id_clmnt: '600036156',
              ptcpnt_id_vet: '600036156',
              ptcpnt_suspns_id: '600276939',
              soj_lctn_id: '347'
            }
          end
          let(:claims) { { benefit_claims: [claim] } }

          it 'existing special issues are left unchanged' do
            expected_claim_options = claim.dup
            special_issues_payload = special_issues.map { |si| { spis_tc: si } }
            expected_claim_options[:contentions] = [
              { clm_id: claim_id, cntntn_id: '999111', special_issues: special_issues_payload }
            ]
            expect_any_instance_of(BGS::ContentionService).to receive(:manage_contentions).with(expected_claim_options)

            subject.new.perform(contention_id, special_issues, claim_record.id)
          end
        end
      end
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Special Issue Updater Job'
      msg = { 'args' => ['value here', 'second value here', claim_record.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          claim_id: claim_record.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end
end
