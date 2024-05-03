# frozen_string_literal: true

require_relative '../support/helpers/rails_helper'
RSpec.describe 'dependents', skip_json_api_validation: true, type: :request do
  let!(:user) { sis_user(ssn: '796043735') }

  describe '#index' do
    it 'returns a list of dependents' do
      expected_data = [
        {
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

      expect(response).to have_http_status(:ok)
      response_without_ids = response.parsed_body['data'].each { |dependent| dependent.delete('id') }
      expect(response_without_ids).to eq(expected_data)
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

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq(expected_response)
      end
    end
  end

  describe '#create' do
    let(:dependency_claim) { build(:dependency_claim) }
    let(:test_form) { dependency_claim.parsed_form }

    context 'with valid input' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        allow(VBMS::SubmitDependentsPdfJob).to receive(:perform_sync)
      end

      it 'returns job ids' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post('/mobile/v0/dependents', params: test_form, headers: sis_headers)
        end
        expect(response).to have_http_status(:accepted)
        submit_form_job_id = BGS::SubmitForm686cJob.jobs.first['jid']
        expect(response.parsed_body).to eq({ 'data' => { 'submitFormJobId' => submit_form_job_id } })
      end
    end

    context 'with failed sync job perform' do
      before do
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_686?).and_return(true)
        allow_any_instance_of(SavedClaim::DependencyClaim).to receive(:submittable_674?).and_return(true)
        allow(VBMS::SubmitDependentsPdfJob).to receive(:perform_sync)
          .and_raise(Common::Exceptions::BackendServiceException)
        allow_any_instance_of(BGS::DependentService).to receive(:submit_to_central_service)
      end

      it 'returns error' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          post('/mobile/v0/dependents', params: test_form, headers: sis_headers)
        end
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to eq({ 'errors' => [
                                             { 'title' => 'Operation failed',
                                               'detail' => 'Operation failed',
                                               'code' => 'VA900', 'status' => '400' }
                                           ] })
      end
    end
  end
end
