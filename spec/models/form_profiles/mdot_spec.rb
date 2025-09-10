# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormProfiles::MDOT, type: :model do
  let(:user_details) do
    {
      first_name: 'Greg',
      last_name: 'Anderson',
      middle_name: 'A',
      birth_date: '19910405',
      ssn: '000550237'
    }
  end

  let(:user) { build(:user, :loa3, user_details) }

  describe '#prefill_form' do
    it 'prefills the MDOT form' do
      VCR.insert_cassette(
        'mdot/get_supplies_200',
        match_requests_on: %i[method uri headers],
        erb: { icn: user.icn }
      )
      form_data = FormProfile.for(form_id: 'MDOT', user:).prefill[:form_data]
      errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['MDOT'], form_data)
      expect(errors).to be_empty
      VCR.eject_cassette
    end

    it 'catches no-supplies 200' do
      VCR.insert_cassette(
        'mdot/get_supplies_200_no_supplies',
        match_requests_on: %i[method uri]
      )
      form_data = FormProfile.for(form_id: 'MDOT', user:).prefill[:form_data]
      errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['MDOT'], form_data)
      schema_error = errors.any? do |error|
        error.include?("did not contain a required property of 'supplies' in schema")
      end
      expect(schema_error).to be(true)
      VCR.eject_cassette
    end

    context 'with assistive devices' do
      it 'still prefills the MDOT form' do
        VCR.insert_cassette(
          'mdot/get_supplies_assistive_devices_200',
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        )
        form_data = FormProfile.for(form_id: 'MDOT', user:).prefill[:form_data]
        errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['MDOT'], form_data)
        expect(errors).to be_empty
        VCR.eject_cassette
      end
    end

    context 'with null addresses' do
      it 'still prefills the MDOT form' do
        VCR.insert_cassette(
          'mdot/get_supplies_null_addresses_200',
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        )
        form_data = FormProfile.for(form_id: 'MDOT', user:).prefill[:form_data]
        errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['MDOT'], form_data)
        expect(errors).to be_empty
        VCR.eject_cassette
      end
    end

    context 'with errors' do
      it 'handles 500 responses from system-of-record' do
        VCR.insert_cassette(
          'mdot/get_supplies_500',
          match_requests_on: %i[method uri headers],
          erb: { icn: user.icn }
        )
        expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
          .to raise_error(Common::Exceptions::BackendServiceException)
        VCR.eject_cassette
      end

      it 'handles 401 responses from system-of-record' do
        VCR.insert_cassette(
          'mdot/get_supplies_401',
          match_requests_on: %i[method uri],
          erb: { icn: user.icn }
        )
        expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
          .to raise_error(Common::Exceptions::BackendServiceException)
        VCR.eject_cassette
      end

      it 'handles 406 responses from system-of-record' do
        VCR.insert_cassette(
          'mdot/simulated_get_supplies_406',
          match_requests_on: %i[method uri],
          erb: { icn: user.icn }
        )
        expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
          .to raise_error(Common::Exceptions::BackendServiceException)
        VCR.eject_cassette
      end

      it 'handles 410 responses from system-of-record' do
        VCR.insert_cassette(
          'mdot/simulated_get_supplies_410',
          match_requests_on: %i[method uri],
          erb: { icn: user.icn }
        )
        expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
          .to raise_error(Common::Exceptions::BackendServiceException)
        VCR.eject_cassette
      end

      it 'handles non-JSON responses from system-of-record' do
        VCR.insert_cassette(
          'mdot/simulated_get_supplies_200_not_json',
          match_requests_on: %i[method uri],
          erb: { icn: user.icn }
        )
        expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
          .to raise_error(Common::Exceptions::BackendServiceException)
        VCR.eject_cassette
      end
    end

    it 'handles 401 (missing header) responses from system-of-record' do
      VCR.insert_cassette(
        'mdot/get_supplies_401_missing_header',
        match_requests_on: %i[method uri]
      )
      expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
        .to raise_error(Common::Exceptions::BackendServiceException)
      VCR.eject_cassette
    end

    it 'handles 401 (patient not found) responses from system-of-record' do
      VCR.insert_cassette(
        'mdot/get_supplies_401_patient_not_found.yml',
        match_requests_on: %i[method uri]
      )
      expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
        .to raise_error(Common::Exceptions::BackendServiceException)
      VCR.eject_cassette
    end

    it 'handles 400 responses from system-of-record' do
      VCR.insert_cassette(
        'mdot/get_supplies_400.yml',
        match_requests_on: %i[method uri]
      )
      expect { FormProfile.for(form_id: 'MDOT', user:).prefill }
        .to raise_error(Common::Exceptions::BackendServiceException)
      VCR.eject_cassette
    end
  end
end
