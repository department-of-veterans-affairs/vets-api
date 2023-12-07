# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe 'dependents', type: :request do
  let!(:user) { sis_user }

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
end
