# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Dependents', type: :request do
  include CommitteeHelper

  let!(:user) { sis_user(ssn: '796043735') }

  describe '#index' do
    it 'returns a list of dependents' do
      expected_data = [
        {
          'id' => UUID_REGEX,
          'type' => 'dependents',
          'attributes' => {
            'awardIndicator' => 'N',
            'dateOfBirth' => '01/02/1960',
            'emailAddress' => 'test@email.com',
            'firstName' => 'JANE',
            'lastName' => 'WEBB',
            'middleName' => 'M',
            'proofOfDependency' => nil,
            'ptcpntId' => '600140899',
            'relatedToVet' => 'Y',
            'relationship' => 'Spouse',
            'veteranIndicator' => 'N'
          }
        },
        {
          'id' => UUID_REGEX,
          'type' => 'dependents',
          'attributes' => {
            'awardIndicator' => 'N',
            'dateOfBirth' => '02/04/2002',
            'emailAddress' => 'test@email.com',
            'firstName' => 'MARK',
            'lastName' => 'WEBB',
            'middleName' => nil,
            'proofOfDependency' => 'N',
            'ptcpntId' => '600280661',
            'relatedToVet' => 'Y',
            'relationship' => 'Child',
            'veteranIndicator' => 'N'
          }
        }
      ]

      VCR.use_cassette('bgs/claimant_web_service/dependents') do
        get('/mobile/v0/dependents', params: { id: user.participant_id }, headers: sis_headers)
      end

      assert_schema_conform(200)
      expect(response.parsed_body['data'].to_a).to match(expected_data)
    end

    context 'with an erroneous bgs response' do
      it 'returns error response' do
        expected_response = {
          'errors' => [
            { 'title' => 'Operation failed',
              'detail' => 'wrong number of arguments (given 0, expected 1..2)', 'code' => 'VA900', 'status' => '400' }
          ]
        }
        allow_any_instance_of(BGS::DependentService).to receive(:get_dependents).and_raise(BGS::ShareError)
        get('/mobile/v0/dependents', params: { id: user.participant_id }, headers: sis_headers)

        assert_schema_conform(400)
        expect(response.parsed_body).to eq(expected_response)
      end
    end
  end

  describe '#create' do
    let(:dependency_claim) { build(:dependency_claim_v2) }
    let(:test_form) { dependency_claim.parsed_form }

    context 'with valid input' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        allow_any_instance_of(BGS::DependentService).to receive(:submit_pdf_job)
      end

      it 'returns job ids' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post('/mobile/v0/dependents', params: test_form, headers: sis_headers)
        end

        assert_schema_conform(202)
        submit_form_job_id = BGS::SubmitForm686cV2Job.jobs.first['jid']
        expect(response.parsed_body['data'].to_h).to match(
          {
            'id' => UUID_REGEX,
            'type' => 'dependents',
            'attributes' => {
              'submitFormJobId' => submit_form_job_id
            }
          }
        )
      end
    end

    context 'with failed sync job perform' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
      end

      it 'submits to central service' do
        expect_any_instance_of(BGS::DependentService).to receive(:submit_to_central_service).with(
          claim: instance_of(SavedClaim::DependencyClaim), encrypted_vet_info: instance_of(String)
        )
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post('/mobile/v0/dependents', params: test_form, headers: sis_headers)
        end
      end
    end
  end
end
