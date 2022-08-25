# frozen_string_literal: true

require 'rails_helper'

describe 'LGY API' do
  context 'when user is signed in' do
    let(:user) { create(:evss_user, :loa3) }

    before { sign_in_as user }

    describe 'GET v0/coe/status' do
      context 'when determination is eligible and application is 404' do
        it 'response code is 200' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              expect(response).to have_http_status(:ok)
            end
          end
        end

        it 'response is in JSON format' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              expect(response.content_type).to eq('application/json; charset=utf-8')
            end
          end
        end

        it 'response status key is ELIGIBLE' do
          VCR.use_cassette 'lgy/determination_eligible' do
            VCR.use_cassette 'lgy/application_not_found' do
              get '/v0/coe/status'
              json_body = JSON.parse(response.body)
              expect(json_body['data']['attributes']).to include 'status' => 'ELIGIBLE'
            end
          end
        end
      end
    end

    describe 'GET v0/coe/download' do
      context 'when COE file exists' do
        before do
          @lgy_service = double('LGY Service')
          # Simulate http response object
          @res = OpenStruct.new(body: File.read('spec/fixtures/files/lgy_file.pdf'))
          allow(@lgy_service).to receive(:get_coe_file).and_return @res
          allow_any_instance_of(V0::CoeController).to receive(:lgy_service) { @lgy_service }
        end

        it 'response code is 200' do
          get '/v0/coe/download_coe'
          expect(response).to have_http_status(:ok)
        end

        it 'response is in PDF format' do
          get '/v0/coe/download_coe'
          expect(response.content_type).to eq('application/pdf')
        end

        it 'response body is correct' do
          get '/v0/coe/download_coe'
          expect(response.body).to eq @res.body
        end
      end
    end

    describe 'POST v0/coe/document_upload' do
      context 'when uploading attachments' do
        it 'uploads the file successfully' do
          VCR.use_cassette 'lgy/document_upload' do
            attachments = {
              'files' => [{
                'file' => Base64.encode64(File.read('spec/fixtures/files/lgy_file.pdf')),
                'document_type' => 'VA home loan documents',
                'file_type' => 'pdf',
                'file_name' => 'lgy_file.pdf'
              }]
            }

            post('/v0/coe/document_upload', params: attachments)
            expect(response.status).to eq 200
          end
        end
      end
    end

    describe 'GET v0/coe/document_download' do
      context 'when document exists' do
        before do
          @lgy_service = double('LGY Service')
          # Simulate http response object
          @res = OpenStruct.new(body: File.read('spec/fixtures/files/lgy_file.pdf'))
          allow(@lgy_service).to receive(:get_document).and_return @res
          allow_any_instance_of(V0::CoeController).to receive(:lgy_service) { @lgy_service }
        end

        it 'response code is 200' do
          get '/v0/coe/document_download/123456789'
          expect(response).to have_http_status(:ok)
        end

        it 'response is in PDF format' do
          get '/v0/coe/document_download/123456789'
          expect(response.content_type).to eq('application/pdf')
        end

        it 'response body is correct' do
          get '/v0/coe/document_download/123456789'
          expect(response.body).to eq @res.body
        end
      end
    end
  end
end
