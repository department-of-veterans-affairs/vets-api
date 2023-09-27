# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ReportUnsuccessfulSubmissions, type: :job do
  let(:upload_claims) do
    upload_claims = []
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: nil))
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: 'random string'))
    evss_response_array = [{ 'key' => 'key-here', 'severity' => 'FATAL', 'text' => 'message-here' }]
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: evss_response_array))
    upload_claims.push(FactoryBot.create(:auto_established_claim,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: evss_response_array.to_json))
    upload_claims.push(FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: evss_response_array.to_json))
    upload_claims.push(FactoryBot.create(:auto_established_claim_without_flashes_or_special_issues,
                                         :status_errored,
                                         cid: '0oa9uf05lgXYk6ZXn297',
                                         evss_response: evss_response_array.to_json))
  end
  let(:pending_claims) { FactoryBot.create(:auto_established_claim, cid: '0oa9uf05lgXYk6ZXn297') }
  let(:poa_submissions) do
    poa_submissions = []
    poa_submissions.push(FactoryBot.create(:power_of_attorney,
                                           cid: '0oa9uf05lgXYk6ZXn297'))
    poa_submissions.push(FactoryBot.create(:power_of_attorney,
                                           cid: '0oa9uf05lgXYk6ZXn297'))
    poa_submissions.push(FactoryBot.create(:power_of_attorney,
                                           cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:errored_poa_submissions) do
    errored_poa_submissions = []
    errored_poa_submissions.push(FactoryBot.create(:power_of_attorney, :errored, cid: '0oa9uf05lgXYk6ZXn297'))
    errored_poa_submissions.push(FactoryBot.create(
                                   :power_of_attorney,
                                   :errored,
                                   vbms_error_message: 'File could not be retrieved from AWS',
                                   cid: '0oa9uf05lgXYk6ZXn297'
                                 ))
    errored_poa_submissions.push(FactoryBot.create(:power_of_attorney_without_doc, cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:evidence_waiver_submissions) do
    evidence_waiver_submissions = []
    evidence_waiver_submissions.push(FactoryBot.create(:claims_api_evidence_waiver_submission,
                                                       cid: '0oa9uf05lgXYk6ZXn297'))
    evidence_waiver_submissions.push(FactoryBot.create(:claims_api_evidence_waiver_submission,
                                                       cid: '0oa9uf05lgXYk6ZXn297'))
    evidence_waiver_submissions.push(FactoryBot.create(:claims_api_evidence_waiver_submission,
                                                       cid: '0oa9uf05lgXYk6ZXn297'))
  end
  let(:errored_evidence_waiver_submissions) do
    errored_evidence_waiver_submissions = []
    errored_evidence_waiver_submissions.push(FactoryBot.create(:claims_api_evidence_waiver_submission, :errored,
                                                               cid: '0oa9uf05lgXYk6ZXn297'))
    errored_evidence_waiver_submissions.push(FactoryBot.create(
                                               :claims_api_evidence_waiver_submission,
                                               :errored,
                                               vbms_error_message: 'File could not be retrieved from AWS',
                                               cid: '0oa9uf05lgXYk6ZXn297'
                                             ))
    errored_evidence_waiver_submissions.push(FactoryBot.create(:claims_api_evidence_waiver_submission,
                                                               cid: '0oa9uf05lgXYk6ZXn297'))
  end

  describe '#perform' do
    let(:from) { 1.day.ago }
    let(:to) { Time.zone.now }
    let(:cid) { '0oa9uf05lgXYk6ZXn297' }
    let(:unsuccessful_poa_submissions) do
      ClaimsApi::PowerOfAttorney.where(created_at: from..to,
                                       status: 'errored')
                                .order(:cid, :status)
                                .pluck(:cid, :status, :id, :created_at)
    end

    it 'sends mail' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = 1.day.ago
        expect(ClaimsApi::UnsuccessfulReportMailer).to receive(:build).once.with(
          from,
          to,
          consumer_claims_totals: [],
          unsuccessful_claims_submissions: ClaimsApi::AutoEstablishedClaim.where(created_at: from..to,
                                                                                 status: 'errored')
                                                                      .order(:cid, :status)
                                                                      .pluck(:cid, :status, :id),
          poa_totals: [],
          unsuccessful_poa_submissions: [],
          ews_totals: [],
          unsuccessful_evidence_waiver_submissions: [],
          itf_totals: []
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end

    it 'calculate totals' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        upload_claims.push(pending_claims)
        pending_claims

        special_issues = upload_claims.map { |claim| claim[:special_issues].length.positive? ? 1 : 0 }.sum
        flashes = upload_claims.map { |claim| claim[:flashes].length.positive? ? 1 : 0 }.sum

        report = described_class.new
        report.perform
        claims_totals = report.claims_totals

        expected_issues = "#{((special_issues.to_f / claims_totals[0]['VA TurboClaim'][:totals]) * 100).round(2)}%"
        expected_flash = "#{((flashes.to_f / claims_totals[0]['VA TurboClaim'][:totals]) * 100).round(2)}%"

        expect(claims_totals.first.keys).to eq(['VA TurboClaim'])
        expect(claims_totals[0]['VA TurboClaim'][:percentage_with_flashes]).to eq(expected_flash)
        expect(claims_totals[0]['VA TurboClaim'][:percentage_with_special_issues].to_s).to eq(expected_issues)
      end
    end

    it 'includes POA metrics' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        poa_submissions
        errored_poa_submissions

        job = described_class.new
        job.perform
        poa_totals = job.poa_totals
        unsuccessful_poa_submissions = job.unsuccessful_poa_submissions

        expect(poa_totals[0]['VA TurboClaim'][:totals]).to eq(6)
        expect(unsuccessful_poa_submissions.count).to eq(2)
        expect(unsuccessful_poa_submissions[0][:cid]).to eq('0oa9uf05lgXYk6ZXn297')
      end
    end

    it 'includes ews metrics' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        evidence_waiver_submissions
        errored_evidence_waiver_submissions

        job = described_class.new
        job.perform
        ews_totals = job.ews_totals
        unsuccessful_evidence_waiver_submissions = job.unsuccessful_evidence_waiver_submissions

        expect(ews_totals[0]['VA TurboClaim'][:totals]).to eq(6)
        expect(unsuccessful_evidence_waiver_submissions.count).to eq(2)
        expect(unsuccessful_evidence_waiver_submissions[0][:cid]).to eq('0oa9uf05lgXYk6ZXn297')
      end
    end

    it 'includes ITF metrics' do
      with_settings(Settings.claims_api,
                    report_enabled: true) do
        ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::SUBMITTED, cid: '0oa9uf05lgXYk6ZXn297')
        ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::ERRORED, cid: '0oa9uf05lgXYk6ZXn297')

        ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::SUBMITTED, cid: '0oadnb0o063rsPupH297')
        ClaimsApi::IntentToFile.create!(status: ClaimsApi::IntentToFile::ERRORED, cid: '0oadnb0o063rsPupH297')

        job = described_class.new
        job.perform
        itf_totals = job.itf_totals

        expect(itf_totals[0]['VA TurboClaim'][:submitted]).to eq(1)
        expect(itf_totals[0]['VA TurboClaim'][:errored]).to eq(1)
        expect(itf_totals[0]['VA TurboClaim'][:totals]).to eq(2)

        expect(itf_totals[1]['VA Connect Pro'][:submitted]).to eq(1)
        expect(itf_totals[1]['VA Connect Pro'][:errored]).to eq(1)
        expect(itf_totals[1]['VA Connect Pro'][:totals]).to eq(2)
      end
    end
  end
end
