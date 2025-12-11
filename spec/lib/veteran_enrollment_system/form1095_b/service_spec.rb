# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/form1095_b/service'

RSpec.describe VeteranEnrollmentSystem::Form1095B::Service do
  let(:tax_year) { 2024 }
  let(:icn) { '1012667145V762142' }

  describe '#get_form_by_icn' do
    context 'when the request is successful' do
      it 'returns the form data from the enrollment system' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_success',
                         { match_requests_on: %i[method uri] }) do
          response = subject.get_form_by_icn(icn:, tax_year:)

          expect(response).to eq(
            {
              'data' => {
                'issuer' => {
                  'issuerName' => 'US Department of Veterans Affairs',
                  'ein' => '54-2002017',
                  'contactPhoneNumber' => '877-222-8387',
                  'address' => {
                    'street1' => 'PO Box 149975',
                    'city' => 'Austin',
                    'stateOrProvince' => 'TX',
                    'zipOrPostalCode' => '78714-8975',
                    'country' => 'USA'
                  }
                },
                'responsibleIndividual' => {
                  'name' => { 'firstName' => 'HECTOR', 'lastName' => 'ALLEN' },
                  'address' => {
                    'street1' => 'PO BOX 494',
                    'city' => 'MOCA',
                    'stateOrProvince' => 'PR',
                    'zipOrPostalCode' => '00676-0494',
                    'country' => 'USA'
                  },
                  'ssn' => '796126859',
                  'dateOfBirth' => '19320205'
                },
                'coveredIndividual' => {
                  'name' => { 'firstName' => 'HECTOR', 'lastName' => 'ALLEN' },
                  'ssn' => '796126859',
                  'dateOfBirth' => '19320205',
                  'coveredAll12Months' => false,
                  'monthsCovered' => ['MARCH']
                },
                'taxYear' => '2024'
              },
              'messages' => []
            }
          )
        end
      end
    end

    context 'when an error status is received' do
      it 'increments StatsD and raises the appropriate error' do
        VCR.use_cassette('veteran_enrollment_system/form1095_b/get_form_not_found',
                         { match_requests_on: %i[method uri] }) do
          expect(StatsD).to receive(:increment).with('api.form1095b_enrollment.get_form_by_icn.fail',
                                                     { tags: ['error:CommonExceptionsResourceNotFound'] })
          expect(StatsD).to receive(:increment).with('api.form1095b_enrollment.get_form_by_icn.total')
          expect { subject.get_form_by_icn(icn:, tax_year:) }.to \
            raise_error(Common::Exceptions::ResourceNotFound, 'Resource not found') do |error|
            expect(error.errors.first.detail).to eq(
              'No enrollments found for the provided ICN [REDACTED] with tax year 2024.'
            )
          end
        end
      end
    end
  end
end
