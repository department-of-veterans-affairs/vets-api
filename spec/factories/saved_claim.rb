# frozen_string_literal: true

FactoryBot.define do
  class SavedClaim::TEST < SavedClaim
    FORM = '55p_9999ez'

    def email
      parsed_form['email']
    end
  end

  factory :fake_saved_claim, class: 'SavedClaim::TEST' do
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
  end

end
