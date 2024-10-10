# frozen_string_literal: true

RSpec.shared_examples 'shared reporting behavior' do
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
      # TODO: address in API-40862-dynamic-email-report-preview
      # expect(unsuccessful_poa_submissions.count).to eq(2)
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
      # TODO: address in API-40862-dynamic-email-report-preview
      # expect(unsuccessful_evidence_waiver_submissions.count).to eq(2)
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

  it 'includes 526EZ claims from VaGov' do
    with_settings(Settings.claims_api, report_enabled: true) do
      create(:auto_established_claim_va_gov, created_at: Time.zone.now).freeze
      create(:auto_established_claim_va_gov, created_at: Time.zone.now).freeze
      create(:auto_established_claim_va_gov, :transaction_id_25, created_at: Time.zone.now).freeze
      create(:auto_established_claim_va_gov, :transaction_id_25, created_at: Time.zone.now).freeze

      job = described_class.new
      job.perform
      va_gov_groups = job.unsuccessful_va_gov_claims_submissions

      expect(va_gov_groups).to include('A')
      expect(va_gov_groups).to include('B')
      expect(va_gov_groups).to include('C')
      expect(va_gov_groups['A'][0][:transaction_id]).to be_a(String)
      expect(va_gov_groups['A'][0][:id]).to be_a(String)
    end
  end
end
