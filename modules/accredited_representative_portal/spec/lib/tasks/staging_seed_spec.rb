# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/tasks/seed/staging_seed'

RSpec.describe AccreditedRepresentativePortal::StagingSeeds,
               skip: 'takes 2 mins and code it is testing will not be modified further' do
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
      described_class.run
      requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest.all

      expect(requests).to(be_all do |req|
        req.power_of_attorney_form.parsed_data['veteran'].present?
      end)

      # expect dependent data if claimant_type is dependent
      expect(requests.where(claimant_type: 'dependent')).to(be_all do |req|
        req.power_of_attorney_form.parsed_data['dependent'].present?
      end)

      # Verify form data is structured correctly
      forms = AccreditedRepresentativePortal::PowerOfAttorneyForm.all
      expect(forms).to(be_all do |form|
        data = form.parsed_data
        data['veteran'].present? &&
        data['authorizations'].present?
      end)
    end

    it 'creates the expected mix of requests' do
      described_class.run

      # Get all requests
      requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest.all

      # Basic resolution counts
      expect(requests.resolved.count).to be_positive
      expect(requests.unresolved.count).to be_positive

      # Basic claimant type counts
      veteran_count = requests.where(claimant_type: 'veteran').count
      dependent_count = requests.where(claimant_type: 'dependent').count

      expect(veteran_count).to be_positive
      expect(dependent_count).to be_positive

      # Verify form data matches claimant type
      veteran_requests = requests.where(claimant_type: 'veteran')
      dependent_requests = requests.where(claimant_type: 'dependent')

      veteran_requests.each do |req|
        expect(req.power_of_attorney_form.parsed_data['veteran']).to be_present
        expect(req.power_of_attorney_form.parsed_data['dependent']).to be_nil
      end

      dependent_requests.each do |req|
        expect(req.power_of_attorney_form.parsed_data['dependent']).to be_present
      end
    end

    it 'creates requests for multi-org reps' do
      multi_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                           .where(accredited_individual_registration_number: 'MR789')
      expect(multi_rep_requests.pluck(:power_of_attorney_holder_poa_code))
        .to include('008', 'ABC', 'XYZ')
      # verify they all have orgs
      expect(multi_rep_requests).to(be_all { |req| req.accredited_organization.present? })
    end

    it 'creates user account associations for all representatives' do
      associations = AccreditedRepresentativePortal::UserAccountAccreditedIndividual.all
      representatives = Veteran::Service::Representative.all

      # Should create one association per rep
      expect(associations.count).to eq(representatives.count)

      # Check email pattern
      expect(associations).to(be_all do |assoc|
        assoc.user_account_email.match?(/vets\.gov\.user\+\d+@gmail\.com/)
      end)

      # Verify registration numbers match reps
      expect(associations.pluck(:accredited_individual_registration_number))
        .to match_array(representatives.pluck(:representative_id))

      # Check holder type
      expect(associations).to(be_all do |assoc|
        assoc.power_of_attorney_holder_type == 'veteran_service_organization'
      end)
    end

    it 'creates the expected pattern of requests per representative and organization' do
      # Focus on CT org (008) and digital_only_rep who only works with CT
      ct_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                        .where(
                          accredited_individual_registration_number: digital_only_rep.representative_id,
                          power_of_attorney_holder_poa_code: ct_digital_org.poa
                        )

      # Total count for this org-rep pair
      expect(ct_rep_requests.count).to eq(5)

      # Resolution counts
      expect(ct_rep_requests.unresolved.count).to eq(3)
      resolved = ct_rep_requests.resolved
      expect(resolved.count).to eq(2)
    end
  end
end
