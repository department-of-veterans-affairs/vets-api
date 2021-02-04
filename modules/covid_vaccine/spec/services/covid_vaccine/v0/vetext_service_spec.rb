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
      VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_200', match_requests_on: %i[method path]) do
        response = subject.put_vaccine_registry(registry_attributes)
        expect(response[:sid]).to eq('FA82BF279B8673EDF2160766351113753298')
      end
    end

    it 'raises a BackendServiceException with invalid attribute' do
      exception_arguments = {
        detail: 'Unrecognized field dateVaccineReeceived',
        code: 'VETEXT_400',
        source: 'POST: /api/vetext/pub/covid/vaccine/registry'
      }
      exception_message = "BackendServiceException: #{exception_arguments}"
      VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_400', match_requests_on: %i[method path]) do
        expect { subject.put_vaccine_registry(date_vaccine_reeceived: '') }
          .to raise_error(Common::Exceptions::BackendServiceException, exception_message)
      end
    end

    it 'raises a BackendServiceException on a 500 error' do
      VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_500', match_requests_on: %i[method path]) do
        expect { subject.put_vaccine_registry(registry_attributes) }
          .to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_502/)
      end
    end

    it 'raises a BackendServiceException on a 599 error' do
      VCR.use_cassette('covid_vaccine/vetext/post_vaccine_registry_599', match_requests_on: %i[method path]) do
        expect { subject.put_vaccine_registry(registry_attributes) }
          .to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end

  describe '#put_email_opt_out' do
    it 'opts a users email out of future emails' do
      VCR.use_cassette('covid_vaccine/vetext/create_and_opt_out', match_requests_on: %i[method path]) do
        create_response = subject.put_vaccine_registry(registry_attributes)
        opt_response = subject.put_email_opt_out(create_response[:sid])
        expect(opt_response[:success]).to be_truthy
      end
    end

    it 'returns a 400 when supplied with a nonexistent SID' do
      VCR.use_cassette('covid_vaccine/vetext/opt_out_nonexistent', match_requests_on: %i[method path]) do
        expect { subject.put_email_opt_out(SecureRandom.uuid) }
          .to raise_error(Common::Exceptions::BackendServiceException, /VETEXT_400/)
      end
    end
  end

  describe 'put_email_opt_in' do
    let(:inactive_sid) { 'FA82BF279B8673EDF2160766351113753298' }

    it 'opts a users email in on future emails' do
      VCR.use_cassette('covid_vaccine/vetext/create_and_opt_in', match_requests_on: %i[method path]) do
        create_response = subject.put_vaccine_registry(registry_attributes)
        opt_response = subject.put_email_opt_in(create_response[:sid])
        expect(opt_response[:success]).to be_truthy
      end
    end
  end
end
