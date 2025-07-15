# frozen_string_literal: true

require 'rails_helper'
require 'veteran_enrollment_system/form1095_b/service'

RSpec.describe VeteranEnrollmentSystem::Form1095B::Service do
  let(:tax_year) { 2024 }
  let(:icn) { '1012667145V762142' }

  describe '#get_form_by_icn' do
    context 'when the request is successful' do
      it 'returns the form data from the enrollment system' do
        VCR.use_cassette('veteran_enrollment_system/form1095b/get_form_success', { match_requests_on: %i[method uri] }) do
          response = subject.get_form_by_icn(icn:, tax_year:)

          expect(response).to eq(
            { 'data' =>
              { 'issuer' =>
                { 'issuerName' => 'US Department of Veterans Affairs',
                  'ein' => '54-2002017',
                  'contactPhoneNumber' => '877-222-8387',
                  'address' =>
                  { 'street1' => 'PO Box 149975',
                    'city' => 'Austin',
                    'stateOrProvince' => 'TX',
                    'zipOrPostalCode' => '78714-8975',
                    'country' => 'USA' } },
                'responsibleIndividual' =>
                { 'name' => { 'firstName' => 'VGSSFIFTYSIX', 'lastName' => 'TESTFIFTYSIX' },
                  'address' =>
                  { 'street1' => '3015 ASHBURTON MANOR DR',
                    'city' => 'HERNDON',
                    'stateOrProvince' => 'VA',
                    'zipOrPostalCode' => '20171-2270',
                    'country' => 'USA' },
                  'ssn' => '101990920',
                  'dateOfBirth' => '19530907' },
                'coveredIndividual' =>
                { 'name' => { 'firstName' => 'VGSSFIFTYSIX', 'lastName' => 'TESTFIFTYSIX' },
                  'ssn' => '101990920',
                  'dateOfBirth' => '19530907',
                  'coveredAll12Months' => false,
                  'monthsCovered' => [] },
                'taxYear' => '2024' },
              'messages' => [] }
          )
        end
      end
    end

    context 'when an error status is received' do
      it 'raises an error' do
        VCR.use_cassette('veteran_enrollment_system/form1095b/get_form_error') do
          expect { subject.get_form_by_icn(icn:, tax_year:) }.to raise_error(Common::Client::Errors::ClientError)
        end
      end
    end
  end
end
