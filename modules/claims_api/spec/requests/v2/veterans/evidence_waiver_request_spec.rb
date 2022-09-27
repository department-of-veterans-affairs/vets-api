# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'

RSpec.describe 'Evidence Waiver 5103', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:sub_path) { "/services/claims/v2/veterans/#{veteran_id}/5103" }
  let(:scopes) { %w[claim.write] }

  describe '5103 Waiver' do
    describe 'submit' do
      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            context 'when success' do
              it 'returns a 200' do
                allow(JWT).to receive(:decode).and_return(nil)
                allow(Token).to receive(:new).and_return(ccg_token)
                allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)

                post sub_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

                expect(response.status).to eq(200)
              end
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              post sub_path, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end
  end
end
