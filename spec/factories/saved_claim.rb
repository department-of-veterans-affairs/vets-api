# frozen_string_literal: true

class SavedClaim::Test < SavedClaim
  FORM = 'Form23-42Fake'

  def email
    parsed_form['email']
  end

  def form_matches_schema
    true
  end

  def attachment_keys
    [:files]
  end
end

FactoryBot.define do
  factory :fake_saved_claim, class: 'SavedClaim::Test' do
    transient do
      form_id { 'Form23-42Fake' }
    end

    form do
      {
        veteranFullName: {
          first: 'Foo',
          last: 'Bar'
        },
        email: 'foo@bar.com',
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '123456789',
        veteranAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        }
      }.to_json
    end

    after(:build) do |saved_claim, evaluator|
      stub_const("#{saved_claim.class}::FORM", evaluator.form_id)
    end

    trait :with_attachments do
      persistent_attachments { create_list(:claim_evidence, 2) }
    end
  end
end
