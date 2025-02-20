# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/tasks/seed/staging_seed'

RSpec.describe AccreditedRepresentativePortal::StagingSeeds do
  # claimants
  let!(:test_accounts) { create_list(:user_account, 10) }

  # Digital VSOs
  let!(:ct_digital_org) do
    create(:organization,
           name: 'Connecticut Veterans Affairs',
           poa: '008',
           can_accept_digital_poa_requests: true)
  end

  let!(:other_digital_org) do
    create(:organization,
           name: 'Digital VSO',
           poa: 'ABC',
           can_accept_digital_poa_requests: true)
  end

  # Non-digital VSO
  let!(:non_digital_org) do
    create(:organization,
           name: 'Paper Only VSO',
           poa: 'XYZ',
           can_accept_digital_poa_requests: false)
  end

  # Representatives with various affiliations
  let!(:digital_only_rep) do
    create(:representative,
           first_name: 'Digital',
           last_name: 'Rep',
           representative_id: 'DR123',
           poa_codes: ['008']) # CT only
  end

  let!(:non_digital_rep) do
    create(:representative,
           first_name: 'Paper',
           last_name: 'Rep',
           representative_id: 'PR456',
           poa_codes: ['XYZ']) # Non-digital only
  end

  let!(:multi_org_rep) do
    create(:representative,
           first_name: 'Multi',
           last_name: 'Rep',
           representative_id: 'MR789',
           poa_codes: %w[008 ABC XYZ]) # Both digital and non-digital
  end

  let!(:no_org_rep) do
    create(:representative,
           first_name: 'Lonely',
           last_name: 'Rep',
           representative_id: 'LR000',
           poa_codes: ['ZZZ']) # No matching org
  end

  describe '.run' do
    before { described_class.run }

    it 'creates POA requests for reps with matching organizations' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.count).to be_positive
    end

    it 'creates POA requests for CT digital org' do
      ct_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                    .where(power_of_attorney_holder_poa_code: '008')
      expect(ct_requests).to exist
      expect(ct_requests).to(be_all { |req| req.accredited_organization == ct_digital_org })
    end

    it 'creates both resolved and unresolved requests' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.processed).to exist
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.not_processed).to exist
    end

    it 'creates requests with proper claimant data' do
      requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest.all

      expect(requests).to(be_all { |req| req.claimant.is_a?(UserAccount) })
      expect(requests).to(be_all { |req| req.claimant_type == 'veteran' })
    end

    it 'creates requests for multi-org reps' do
      multi_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                           .where(accredited_individual_registration_number: 'MR789')
      expect(multi_rep_requests.pluck(:power_of_attorney_holder_poa_code))
        .to include('008', 'ABC', 'XYZ')
      # verify they all have orgs
      expect(multi_rep_requests).to(be_all { |req| req.accredited_organization.present? })
    end
  end
end
