# frozen_string_literal: true

require 'rails_helper'
require 'token_validation/v2/client'
require 'bgs_service/local_bgs'

RSpec.describe 'IntentToFiles', type: :request do
  let(:veteran_id) { '1013062086V794840' }
  let(:iws) do
    ClaimsApi::LocalBGS
  end

  describe 'IntentToFiles' do
    describe 'type' do
      before do
        allow_any_instance_of(iws)
          .to receive(:find_intent_to_file_by_ptcpnt_id_itf_type_cd).and_return(
            stub_response
          )
      end

      let(:type) { 'compensation' }
      let(:itf_type_path) { "/services/claims/v2/veterans/#{veteran_id}/intent-to-file/#{type}" }
      let(:scopes) { %w[system/claim.read] }

      describe 'auth header' do
        let(:stub_response) do
          {
            intent_to_file_id: '1',
            create_dt: Time.zone.now.to_date,
            exprtn_dt: Time.zone.now.to_date + 1.year,
            itf_status_type_cd: 'Active',
            itf_type_cd: 'compensation'
          }
        end

        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              get itf_type_path
              expect(response.status).to eq(401)
            end
          end
        end
      end

      describe "'type' path param" do
        let(:stub_response) do
          {
            intent_to_file_id: '1',
            create_dt: Time.zone.now.to_date,
            exprtn_dt: Time.zone.now.to_date + 1.year,
            itf_status_type_cd: 'Active',
            itf_type_cd: type
          }
        end

        context "when given an invalid 'type' path param" do
          let(:type) { 'some-invalid-value' }

          it 'returns a 400' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header
              expect(response.status).to eq(400)
            end
          end
        end

        context "when given a mixed case 'type' path param" do
          let(:type) { 'CoMpEnSaTiOn' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context "when given an all caps 'type' path param" do
          let(:type) { 'COMPENSATION' }

          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context "when given a valid 'type' path param" do
          context "when given the value 'compensation'" do
            let(:type) { 'compensation' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                get itf_type_path, headers: auth_header
                expect(response.status).to eq(200)
              end
            end
          end

          context "when given the value 'pension'" do
            let(:type) { 'pension' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                get itf_type_path, headers: auth_header
                expect(response.status).to eq(200)
              end
            end
          end

          context "when given the value 'survivor'" do
            let(:type) { 'survivor' }

            it 'returns a 200' do
              with_okta_user(scopes) do |auth_header|
                get itf_type_path, headers: auth_header
                expect(response.status).to eq(200)
              end
            end
          end
        end
      end

      context 'when no record is found in BGS' do
        let(:stub_response) { nil }

        it 'returns a 404' do
          with_okta_user(scopes) do |auth_header|
            get itf_type_path, headers: auth_header
            expect(response.status).to eq(404)
          end
        end
      end

      context 'when multiple ITFs are returned' do
        context "and they're all 'Active'" do
          let(:stub_response) do
            [
              {
                intent_to_file_id: '1',
                create_dt: Time.zone.now.to_date - 1.year,
                exprtn_dt: Time.zone.now.to_date,
                itf_status_type_cd: 'Active',
                itf_type_cd: type
              },
              {
                intent_to_file_id: '2',
                create_dt: Time.zone.now.to_date,
                exprtn_dt: Time.zone.now.to_date + 1.year,
                itf_status_type_cd: 'Active',
                itf_type_cd: type
              }
            ]
          end

          it 'chooses the first non-expired ITF' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header

              parsed_response = JSON.parse(response.body)
              expect(response.status).to eq(200)
              expect(parsed_response['data']['id']).to eq('2')
            end
          end
        end

        context "and none are 'Active'" do
          let(:stub_response) do
            [
              {
                intent_to_file_id: '1',
                create_dt: Time.zone.now.to_date - 1.year,
                exprtn_dt: Time.zone.now.to_date,
                itf_status_type_cd: 'Inactive',
                itf_type_cd: type
              },
              {
                intent_to_file_id: '2',
                create_dt: Time.zone.now.to_date,
                exprtn_dt: Time.zone.now.to_date + 1.year,
                itf_status_type_cd: 'Inactive',
                itf_type_cd: type
              }
            ]
          end

          it 'returns 404' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context "and they're all expired" do
          let(:stub_response) do
            [
              {
                intent_to_file_id: '1',
                create_dt: Time.zone.now.to_date - 1.year,
                exprtn_dt: Time.zone.now.to_date,
                itf_status_type_cd: 'Active',
                itf_type_cd: type
              },
              {
                intent_to_file_id: '2',
                create_dt: Time.zone.now.to_date - 1.year,
                exprtn_dt: Time.zone.now.to_date,
                itf_status_type_cd: 'Active',
                itf_type_cd: type
              }
            ]
          end

          it 'returns 404' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end
      end

      context 'when a single ITF is returned' do
        context 'and it is expired' do
          let(:stub_response) do
            {
              intent_to_file_id: '1',
              create_dt: Time.zone.now.to_date - 1.year,
              exprtn_dt: Time.zone.now.to_date,
              itf_status_type_cd: 'Active',
              itf_type_cd: type
            }
          end

          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end

        context "and it is not 'Active'" do
          let(:stub_response) do
            {
              intent_to_file_id: '1',
              create_dt: Time.zone.now.to_date,
              exprtn_dt: Time.zone.now.to_date + 1.year,
              itf_status_type_cd: 'Inactive',
              itf_type_cd: type
            }
          end

          it 'returns a 404' do
            with_okta_user(scopes) do |auth_header|
              get itf_type_path, headers: auth_header

              expect(response.status).to eq(404)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }
        let(:stub_response) do
          {
            intent_to_file_id: '1',
            create_dt: Time.zone.now.to_date,
            exprtn_dt: Time.zone.now.to_date + 1.year,
            itf_status_type_cd: 'Active',
            itf_type_cd: type
          }
        end
        let(:type) { 'compensation' }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)

              get itf_type_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              get itf_type_path, headers: { 'Authorization' => 'Bearer HelloWorld' }
              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    describe 'submit' do
      before do
        allow_any_instance_of(iws).to receive(:insert_intent_to_file).and_return(
          stub_response
        )
      end

      let(:itf_submit_path) { "/services/claims/v2/veterans/#{veteran_id}/intent-to-file" }
      let(:scopes) { %w[system/claim.write] }
      let(:data) do
        {
          type: 'compensation'
        }
      end
      let(:stub_response) do
        {
          intent_to_file_id: '1',
          create_dt: Time.zone.now.to_date,
          exprtn_dt: Time.zone.now.to_date + 1.year,
          itf_status_type_cd: 'Active',
          itf_type_cd: 'compensation'
        }
      end

      describe 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              post itf_submit_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              post itf_submit_path, params: data
              expect(response.status).to eq(401)
            end
          end
        end
      end

      describe 'submitting a payload' do
        context 'when payload is valid' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              post itf_submit_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when payload is invalid' do
          context "when 'type' is invalid" do
            context "when 'type' is blank" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = ''

                  post itf_submit_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end

            context "when 'type' is nil" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = nil

                  post itf_submit_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end

            context "when 'type' is not an accepted value" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = 'foo'

                  post itf_submit_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end
          end

          context "when ITF type is 'survivor'" do
            context "when optional 'claimantSsn' is provided" do
              it 'returns a 200' do
                with_okta_user(scopes) do |auth_header|
                  survivor_data = data
                  survivor_data[:type] = 'survivor'
                  survivor_data[:claimantSsn] = '123456789'
                  post itf_submit_path, params: survivor_data, headers: auth_header
                  expect(response.status).to eq(200)
                end
              end

              context "when 'claimantSsn' contains separators" do
                it 'returns a 200' do
                  with_okta_user(scopes) do |auth_header|
                    survivor_data = data
                    survivor_data[:type] = 'survivor'
                    survivor_data[:claimantSsn] = '123-45-6789'
                    post itf_submit_path, params: survivor_data, headers: auth_header
                    expect(response.status).to eq(200)
                  end
                end
              end
            end

            context 'when no optional parameters are provided' do
              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  survivor_data = data
                  survivor_data[:type] = 'survivor'
                  post itf_submit_path, params: survivor_data, headers: auth_header
                  expect(response.status).to eq(422)
                end
              end
            end

            context 'when invalid parameter is provided' do
              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  survivor_data = data
                  survivor_data[:type] = 'survivor'
                  survivor_data[:claimantSsn] = 'abcdefghi'
                  post itf_submit_path, params: survivor_data, headers: auth_header
                  expect(response.status).to eq(422)
                end
              end
            end
          end
        end

        context "when 'type' is mixed-case" do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              valid_data = data
              valid_data[:type] = 'CoMpEnSaTiOn'

              post itf_submit_path, params: valid_data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)

              post itf_submit_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              post itf_submit_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    describe 'validate' do
      before do
        allow_any_instance_of(iws).to receive(:insert_intent_to_file).and_return(
          stub_response
        )
      end

      let(:itf_validate_path) { "/services/claims/v2/veterans/#{veteran_id}/intent-to-file/validate" }
      let(:scopes) { %w[system/claim.write] }
      let(:data) do
        {
          type: 'compensation'
        }
      end
      let(:stub_response) do
        {
          intent_to_file_id: '1',
          create_dt: Time.zone.now.to_date,
          exprtn_dt: Time.zone.now.to_date + 1.year,
          itf_status_type_cd: 'Active',
          itf_type_cd: 'compensation'
        }
      end

      describe 'auth header' do
        context 'when provided' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              post itf_validate_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when not provided' do
          it 'returns a 401 error code' do
            with_okta_user(scopes) do
              post itf_validate_path, params: data
              expect(response.status).to eq(401)
            end
          end
        end
      end

      describe 'submitting a payload' do
        context 'when payload is valid' do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              post itf_validate_path, params: data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end

        context 'when payload is invalid' do
          context "when 'type' is survivor" do
            context "when 'claimantSsn' is blank" do
              it 'returns a 422' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = 'survivor'
                  invalid_data[:claimantSsn] = ''
                  post itf_validate_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(422)
                end
              end
            end
          end

          context "when 'type' is invalid" do
            context "when 'type' is blank" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = ''

                  post itf_validate_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end

            context "when 'type' is nil" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = nil

                  post itf_validate_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end

            context "when 'type' is not an accepted value" do
              it 'returns a 400' do
                with_okta_user(scopes) do |auth_header|
                  invalid_data = data
                  invalid_data[:type] = 'foo'

                  post itf_validate_path, params: invalid_data, headers: auth_header
                  expect(response.status).to eq(400)
                end
              end
            end
          end
        end

        context "when 'type' is mixed-case" do
          it 'returns a 200' do
            with_okta_user(scopes) do |auth_header|
              valid_data = data
              valid_data[:type] = 'CoMpEnSaTiOn'

              post itf_validate_path, params: valid_data, headers: auth_header
              expect(response.status).to eq(200)
            end
          end
        end
      end

      context 'CCG (Client Credentials Grant) flow' do
        let(:ccg_token) { OpenStruct.new(client_credentials_token?: true, payload: { 'scp' => [] }) }

        context 'when provided' do
          context 'when valid' do
            it 'returns a 200' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(true)

              post itf_validate_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(200)
            end
          end

          context 'when not valid' do
            it 'returns a 403' do
              allow(JWT).to receive(:decode).and_return(nil)
              allow(Token).to receive(:new).and_return(ccg_token)
              allow_any_instance_of(TokenValidation::V2::Client).to receive(:token_valid?).and_return(false)

              post itf_validate_path, params: data, headers: { 'Authorization' => 'Bearer HelloWorld' }

              expect(response.status).to eq(403)
            end
          end
        end
      end
    end
  end
end
