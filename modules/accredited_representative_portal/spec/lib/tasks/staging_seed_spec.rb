# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/tasks/seed/staging_seed'

RSpec.describe AccreditedRepresentativePortal::StagingSeeds do
  # Test user accounts to be used as claimants
  before(:all) do
    @test_accounts = create_list(:user_account, 10)

    # Create mapped reps
    @mapped_reps = described_class::Constants::REP_EMAIL_MAP.map do |rep_id, _index|
      create(:representative,
             representative_id: rep_id,
             first_name: "First#{rep_id}",
             last_name: "Last#{rep_id}",
             poa_codes: ['008'])
    end

    # Create CT org
    @ct_digital_org = create(:organization,
                             name: 'Connecticut Veterans Affairs',
                             poa: '008',
                             can_accept_digital_poa_requests: true)

    # Create expected user account associations before running seeds
    described_class::Constants::REP_EMAIL_MAP.each do |rep_id, email_index|
      AccreditedRepresentativePortal::UserAccountAccreditedIndividual.create!(
        accredited_individual_registration_number: rep_id,
        user_account_email: "vets.gov.user+#{email_index}@gmail.com",
        power_of_attorney_holder_type: 'veteran_service_organization'
      )
    end

    described_class.run
  end

  after(:all) { DatabaseCleaner.clean_with(:truncation) }

  # Use instance variables in tests
  let(:mapped_reps) { @mapped_reps }
  let(:ct_digital_org) { @ct_digital_org }
  let(:test_accounts) { @test_accounts }

  it 'verifies expected user account mappings exist' do
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

  it 'creates POA requests for CT digital org' do
    ct_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                  .where(power_of_attorney_holder_poa_code: '008')
    expect(ct_requests).to exist
  end

  it 'creates both resolved and unresolved requests' do
    expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.resolved).to exist
    expect(AccreditedRepresentativePortal::PowerOfAttorneyRequest.unresolved).to exist
  end

  it 'creates requests for CT org only' do
    multi_org_rep = mapped_reps.first
    multi_org_rep.update!(poa_codes: %w[008 ABC XYZ])

    multi_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                         .where(accredited_individual_registration_number: multi_org_rep.representative_id)

    expect(multi_rep_requests).to exist
    expect(multi_rep_requests.pluck(:power_of_attorney_holder_poa_code).uniq)
      .to eq(['008'])
    expect(multi_rep_requests.count).to eq(5)
  end

  it 'creates the expected pattern of requests per representative' do
    ct_rep = mapped_reps.first
    ct_rep_requests = AccreditedRepresentativePortal::PowerOfAttorneyRequest
                      .where(accredited_individual_registration_number: ct_rep.representative_id,
                             power_of_attorney_holder_poa_code: '008')

    expect(ct_rep_requests.count).to eq(5)
    expect(ct_rep_requests.resolved.count).to eq(2)
    expect(ct_rep_requests.unresolved.count).to eq(3)
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
end
