# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/tasks/seed/staging_seed'

RSpec.describe AccreditedRepresentativePortal::StagingSeeds do
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
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.count).to be.positive?
    end

    it 'creates POA requests for CT digital org' do
      ct_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                    .where(power_of_attorney_holder_poa_code: '008')
      expect(ct_requests).to exist
    end

    it 'creates both resolved and unresolved requests' do
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.resolved).to exist
      expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.unresolved).to exist
    end

    it 'does not create requests for reps without matching orgs' do
      unmatched_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                           .where(accredited_individual_registration_number: 'LR000')
      expect(unmatched_requests).not_to exist
    end

    it 'creates requests for multi-org reps' do
      multi_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                           .where(accredited_individual_registration_number: 'MR789')
      expect(multi_rep_requests.pluck(:power_of_attorney_holder_poa_code))
        .to include('008', 'ABC', 'XYZ')
    end
  end
end
