# frozen_string_literal: true

require 'rails_helper'

class DummyController
  include AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern
end

RSpec.describe AccreditedRepresentativePortal::V0::RepresentativeFormUploadConcern, type: :controller do
  let(:controller) { DummyController.new }

  describe '#validated_metadata' do
    let(:form_params) do
      {
        'formData' => {
          'veteranSsn' => '123456789',
          'veteranFullName' => { 'first' => 'John', 'last' => 'Doe' },
          'postalCode' => '12345',
          'formNumber' => 'A123',
          'veteranDateOfBirth' => '1980-01-01'
        }
      }
    end

    let(:form_data) do
      {
        'veteranSsn' => '123456789',
        'veteranFullName' => { 'first' => 'John', 'last' => 'Doe' },
        'postalCode' => '12345',
        'formNumber' => 'A123',
        'veteranDateOfBirth' => '1980-01-01'
      }
    end

    before do
      allow(controller).to receive_messages(form_params:, form_data:)
    end

    it 'returns the correct validated metadata' do
      expected_metadata = {
        'veteranFirstName' => 'John',
        'veteranLastName' => 'Doe',
        'fileNumber' => '123456789',
        'zipCode' => '12345',
        'source' => 'VA Platform Digital Forms',
        'docType' => 'A123',
        'businessLine' => 'CMP'
      }

      expect(controller.validated_metadata).to eq(expected_metadata)
    end
  end

  describe '#create_new_form_data' do
    let(:form_params) do
      {
        'formData' => {
          'postalCode' => '12345',
          'email' => 'test@example.com',
          'veteranDateOfBirth' => '1980-01-01'
        }
      }
    end

    let(:form_data) do
      {
        'postalCode' => '12345',
        'email' => 'test@example.com',
        'veteranDateOfBirth' => '1980-01-01'
      }
    end
    let(:ssn) { '123456789' }
    let(:first_name) { 'John' }
    let(:last_name) { 'Doe' }
    let(:birth_date) { '1980-01-01' }

    before do
      allow(controller).to receive_messages(form_params:, form_data:, ssn:,
                                            first_name:, last_name:, birth_date:)
    end

    it 'returns the correct new form data' do
      expected_data = {
        'ssn' => ssn,
        'postalCode' => '12345',
        'full_name' => { 'first' => 'John', 'last' => 'Doe' },
        'email' => 'test@example.com',
        'veteranDateOfBirth' => '1980-01-01'
      }

      expect(controller.create_new_form_data).to eq(expected_data)
    end
  end

  describe '#form_params' do
    let(:params) do
      {
        'confirmationCode' => 'ABC123',
        'location' => '12345',
        'formNumber' => 'A123',
        'formName' => 'Form 123',
        'formData' => {
          'veteranSsn' => '123456789',
          'postalCode' => '12345',
          'veteranDateOfBirth' => '1980-01-01',
          'email' => 'test@example.com',
          'claimantDateOfBirth' => '1985-01-01',
          'claimantFullName' => { 'first' => 'Jane', 'last' => 'Doe' },
          'claimantSsn' => '987654321',
          'veteranFullName' => { 'first' => 'John', 'last' => 'Doe' }
        }
      }
    end

    before do
      allow(controller).to receive(:form_params).and_return(params)
    end

    it 'permits the expected parameters' do
      permitted_params = controller.form_params
      expect(permitted_params).to have_key('confirmationCode')
      expect(permitted_params).to have_key('formData')
      expect(permitted_params['formData']).to have_key('veteranSsn')
      expect(permitted_params['formData']).to have_key('claimantFullName')
    end
  end

  describe '#ssn' do
    let(:form_params_with_claimant_ssn) do
      {
        'formData' => {
          'claimantSsn' => '987654321',
          'veteranSsn' => '123456789'
        }
      }
    end

    let(:form_params_with_veteran_ssn) do
      {
        'formData' => {
          'claimantSsn' => nil,
          'veteranSsn' => '123456789'
        }
      }
    end

    before do
      allow(controller).to receive(:form_params).and_return(form_params_with_claimant_ssn)
    end

    it 'returns claimant ssn if present' do
      expect(controller.ssn).to eq('987654321')
    end

    it 'returns veteran ssn if claimant ssn is nil' do
      allow(controller).to receive(:form_params).and_return(form_params_with_veteran_ssn)
      expect(controller.ssn).to eq('123456789')
    end
  end
end
