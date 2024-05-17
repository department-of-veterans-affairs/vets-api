# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require './modules/claims_api/app/services/claims_api/disability_compensation/docker_container_service'

describe ClaimsApi::DisabilityCompensation::DockerContainerService do
  before do
    stub_claims_api_auth_token
  end

  let(:docker_container_service) { ClaimsApi::DisabilityCompensation::DockerContainerService.new }
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

    temp['data']['attributes']
  end
  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#upload' do
    it 'has a upload method that returns a claim id' do
      VCR.use_cassette('/claims_api/evss/submit') do
        expect(docker_container_service.send(:upload, claim.id)).to be_a(String)
      end
    end
  end
end
