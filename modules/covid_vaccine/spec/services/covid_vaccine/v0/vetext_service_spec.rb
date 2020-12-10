# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::VetextService do
  subject { described_class.new }

  let(:user) { build(:user, :mhv) }
  let(:registry_attributes) do
    {
      vaccine_interest: 'yes',
      authenticated: true,
      date_vaccine_received: '',
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

  describe '#put_vaccine_registry' do
    it 'creates a new vaccine registry with valid attributes' do
      VCR.use_cassette('covid_vaccine/vetext/put_vaccine_registry_200', match_requests_on: %i[method uri]) do
        response = subject.put_vaccine_registry(registry_attributes)
        expect(response[:sid]).to eq('C4471842B588278B6D160738877782115')
      end
    end

    # Need to discuss error handling with VEText developers. This isn't even JSON.
    xit 'raises a BackendServiceException with invalid attribute' do
      VCR.use_cassette('covid_vaccine/vetext/put_vaccine_registry_error', match_requests_on: %i[method uri]) do
        expect { subject.put_vaccine_registry(date_vaccine_reeceived: '') }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
