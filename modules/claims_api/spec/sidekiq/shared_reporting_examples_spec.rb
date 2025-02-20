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
      expect(unsuccessful_poa_submissions[1][:created_at]).to be > 1.day.ago
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
      expect(unsuccessful_evidence_waiver_submissions[1][:created_at]).to be > 1.day.ago
      expect(unsuccessful_evidence_waiver_submissions[0][:cid]).to eq('0oa9uf05lgXYk6ZXn297')
    end
  end

  it 'includes ITF metrics' do
    with_settings(Settings.claims_api,
                  report_enabled: true) do
      create(:intent_to_file, status: 'submitted', cid: '0oa9uf05lgXYk6ZXn297')
      create(:intent_to_file, :itf_errored, cid: '0oa9uf05lgXYk6ZXn297')

      create(:intent_to_file, status: 'submitted', cid: '0oadnb0o063rsPupH297')
      create(:intent_to_file, :itf_errored, cid: '0oadnb0o063rsPupH297')

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
      create(:auto_established_claim_va_gov, :errored, created_at: 2.seconds.ago,
                                                       transaction_id: '467384632187')
      create(:auto_established_claim_va_gov, :errored, created_at: 3.seconds.ago,
                                                       transaction_id: '467384632186')

      job = described_class.new
      job.perform
      va_gov_groups = job.unsuccessful_va_gov_claims_submissions
      first_group = va_gov_groups[1]
      second_group = va_gov_groups[2]

      expect(second_group.count).to eq(1)
      expect(first_group.count).to eq(1)
    end
  end
end
