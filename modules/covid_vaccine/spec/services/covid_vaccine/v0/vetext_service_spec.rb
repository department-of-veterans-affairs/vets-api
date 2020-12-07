# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::VetextService do
  subject { described_class.new }

  let(:user) { build(:user, :mhv) }
  let(:registry_attributes) do
    {
      vaccine_interest: 'yes',
      authenticated: true,
      date_vaccine_reeceived: '',
      contact: true,
      contact_method: 'phone',
      reason_undecided: '',
      first_name: 'Jane',
      last_name: 'Doe',
      date_of_birth: '2/2/1952',
      phone: '555-555-1234',
      email: 'jane.doe@email.com',
      patient_ssn: '000-00-0022'
    }
  end

  describe '#put_vaccine_registry with user' do
    it 'creates a new vaccine registry' do
      VCR.use_cassette('vetext/put_vaccine_registry_with_user', record: :new_episodes) do
        subject.put_vaccine_registry(registry_attributes)
      end
    end
  end
end
