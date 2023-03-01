# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/direct_deposit/service'

RSpec.describe DirectDeposit::Service do
  let(:icn) { '1012666073V986297' }

  before do
    t = Time.zone.local(2022, 1, 30, 10, 0, 0)
    Timecop.freeze(t)

    token = 'eyJraWQiOiJFODRkd0pwZlAzbS1sdnE5SC1ialU1VHR4UVY1bC1wMlZPMGR4X2xrT2RFIiwiYWxnIjoiUlMyNTYifQ.' \
            'eyJ2ZXIiOjEsImp0aSI6IkFULmNEcDlqREZFazVxTEl1d1hMOFh3b0s0R3hhbkNMOTZVWkZ3OWZZU0xGVE0iLCJpc3MiOiJodHR' \
            'wczovL2RlcHR2YS1ldmFsLm9rdGEuY29tL29hdXRoMi9hdXNpMGUyMWhidjVpRWxFaDJwNyIsImF1ZCI6Imh0dHBzOi8vc2FuZGJ' \
            'veC1hcGkudmEuZ292L3NlcnZpY2VzL2RpcmVjdC1kZXBvc2l0LW1hbmFnZW1lbnQiLCJpYXQiOjE2NzY5MTM2MDIsImV4cCI6MTY' \
            '3NjkxNDIwMiwiY2lkIjoiMG9hazlwbm5weTZuR2FTVFoycDciLCJzY3AiOlsiZGlyZWN0LmRlcG9zaXQud3JpdGUiLCJkaXJlY3Q' \
            'uZGVwb3NpdC5yZWFkIl0sInN1YiI6IjBvYWs5cG5ucHk2bkdhU1RaMnA3In0.kBeQ6gsFrtg9IWGJnm3WdNsz5lgRAFYahkrXRmA' \
            '4PXZ6XXU4pDmr993ea0F0e8U3BV2e2BFbBxWLMp7XBr3v7jLJWhJ87dOBZ0Y6tyy_92Z8L8MpLoXhhK8ryDOoD02I-n-xNmLc9RHO' \
            'snKwOO0etEzlJNMCp3ylbiNez1U9g8hXWYiV8FeWKqmxuccLhX6da8QqWJ5BwhztIxG8UUFO1RH29Kv8RbVNw-MjtHBF8yevRx99L' \
            'QPjymflCJCWYw2NbwMzYdNvjyHfouj5HTVOz0A7-C4jz8n2u-4HdAwBk9WYuaC97rwRYbogSjGx-YK8idWz76g6_g5-aSDYw6Ks-Q'

    allow_any_instance_of(DirectDeposit::Configuration).to receive(:access_token).and_return(token)
  end

  describe 'get direct deposit records' do
    context 'when successful' do
      it 'returns a status of 200' do
        service = DirectDeposit::Service.new(icn)

        VCR.use_cassette('lighthouse/direct_deposit/get_valid_200') do
          response = service.get_direct_deposits
          expect(response.status).to eq(200)
        end
      end
    end

    context 'when bad request' do
      it 'returns a status of 400' do
        service = DirectDeposit::Service.new('ABC')

        VCR.use_cassette('lighthouse/direct_deposit/get_invalid_400') do
          response = service.get_direct_deposits
          expect(response.status).to eq(400)
          expect(response.body.message).to eq('Invalid field value')
        end
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        service = DirectDeposit::Service.new(icn)

        VCR.use_cassette('lighthouse/direct_deposit/get_invalid_401') do
          response = service.get_direct_deposits
          expect(response.status).to eq(401)
          expect(response.body.message).to eq('Not Authorized')
        end
      end
    end

    context 'when ICN not found' do
      it 'returns a status of 404' do
        service = DirectDeposit::Service.new('1012829910V765229')

        VCR.use_cassette('lighthouse/direct_deposit/get_invalid_404') do
          response = service.get_direct_deposits
          expect(response.status).to eq(404)
          expect(response.body.message).to eq('Person for ICN not found')
          expect(response.body.detail).to eq('No data found for ICN')
        end
      end
    end

    context 'when bad gateway' do
      it 'returns a status of 502' do
        service = DirectDeposit::Service.new(icn)

        VCR.use_cassette('lighthouse/direct_deposit/get_invalid_502') do
          response = service.get_direct_deposits
          expect(response.status).to eq(502)
          expect(response.body.message).to eq('Required Backend Connection Error')
          expect(response.body.reference).to eq('Backend Connection Error - Failed to retrieve data from MPI')
        end
      end
    end
  end
end
