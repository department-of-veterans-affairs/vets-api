# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

RSpec.describe ClaimsApi::V2::DisabilityCompensationClaimService do
  let(:user) { FactoryBot.create(:user, :loa3) }

  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }

  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp.to_json
  end

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#get_pending_claim' do
    it 'returns claim' do
      service = described_class.new

      returned_claim = service.send(:get_pending_claim, claim.id) # Invoke the protected method using send
      expect(claim).to be_instance_of(ClaimsApi::V2::AutoEstablishedClaim)
      expect(returned_claim.id).to eq(claim.id)
    end
  end

  describe '#set_claim_as_established' do
    it 'updates claim status as ESTABLISHED' do
      service = described_class.new

      service.send(:set_claim_as_established, claim.id)
      claim.reload
      expect(claim.status).to eq('established')
    end
  end

  describe '#set_errored_state' do
    error = OpenStruct.new(
      title: 'Error',
      status_code: '500',
      original_body: 'Error message'
    )

    it 'updates claim status as ERRORED with error details' do
      service = described_class.new

      service.send(:set_errored_state, error, claim.id)
      claim.reload
      expect(claim.status).to eq('errored')
    end
  end

  describe '#log_job_progress' do
    let(:detail) { 'PDF mapper succeeded' }

    it 'logs job progress' do
      service = described_class.new
      expect(ClaimsApi::Logger).to receive(:log).with('compensation_job', claim_id: claim.id, detail:)

      service.send(:log_job_progress, 'compensation_job', claim.id, detail)
    end
  end
end
