# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/tasks/seed/staging_seed'

RSpec.describe AccreditedRepresentativePortal::StagingSeeds do
  # Test user accounts to be used as claimants
  let!(:test_accounts) { create_list(:user_account, 10) }

  let!(:mapped_reps) do
    described_class::Constants::REP_EMAIL_MAP.map do |rep_id, _index|
      create(:representative,
             representative_id: rep_id,
             first_name: "First#{rep_id}",
             last_name: "Last#{rep_id}",
             poa_codes: ['008']) # All mapped reps can work with CT
    end
  end

  # Organizations
  let!(:ct_digital_org) do
    create(:organization,
           name: 'Connecticut Veterans Affairs',
           poa: '008',
           can_accept_digital_poa_requests: true)
  end

  describe '.run' do
    before { described_class.run }

    it 'creates user account associations for mapped representatives' do
      associations = AccreditedRepresentativePortal::UserAccountAccreditedIndividual.all

      # Should have one association per mapped rep
      expect(associations.count).to eq(described_class::Constants::REP_EMAIL_MAP.count)

      # Each rep should have correct email mapping
      described_class::Constants::REP_EMAIL_MAP.each do |rep_id, email_index|
        assoc = associations.find_by(accredited_individual_registration_number: rep_id)
        expect(assoc).to be_present
        expect(assoc.user_account_email).to eq("vets.gov.user+#{email_index}@gmail.com")
        expect(assoc.power_of_attorney_holder_type).to eq('veteran_service_organization')
      end
    end

    it 'creates requests for mapped CT representatives' do
      ct_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                    .where(power_of_attorney_holder_poa_code: '008')

      # Each mapped rep should have exactly 5 requests
      described_class::Constants::REP_EMAIL_MAP.each_key do |rep_id|
        rep_requests = ct_requests.where(accredited_individual_registration_number: rep_id)
        expect(rep_requests.count).to eq(5)

        # Verify mix of resolved/unresolved
        expect(rep_requests.resolved.count).to eq(2)
        expect(rep_requests.unresolved.count).to eq(3)
      end
    end

    it 'creates the expected mix of veteran and dependent requests' do
      requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest.all

      # Each request should have correct form data for its type
      requests.where(claimant_type: 'veteran').find_each do |req|
        form_data = req.power_of_attorney_form.parsed_data
        expect(form_data['veteran']).to be_present
        expect(form_data['dependent']).to be_nil
      end

      requests.where(claimant_type: 'dependent').find_each do |req|
        form_data = req.power_of_attorney_form.parsed_data
        expect(form_data['veteran']).to be_present
        expect(form_data['dependent']).to be_present
      end
    end

    it 'creates requests with proper form data structure' do
      forms = AccreditedRepresentativePortal::PowerOfAttorneyForm.all
      expect(forms).to be_present

      forms.each do |form|
        data = form.parsed_data
        expect(data['authorizations']).to be_present
        expect(data['veteran']).to be_present
      end
    end
  end
end
