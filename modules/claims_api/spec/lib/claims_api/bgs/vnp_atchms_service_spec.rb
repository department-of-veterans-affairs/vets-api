# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_atchms_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'vnp_atchms_service',
    action: 'vnp_atchms_create'
  }
}

describe ClaimsApi::VnpAtchmsService, metadata do
  describe '#vnp_atchms_create', run_at: '2024-04-01T18:48:27Z' do
    subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

    describe 'validation' do
      # get a proc_id from vnp_proc_create
      let(:vnp_proc_id) { '3854593' }
      let(:expected_response) do
        { vnp_proc_id:,
          atchms_file_nm: 'test.pdf',
          atchms_descp: 'test' }
      end

      context 'when missing required params' do
        it 'raises an error' do
          data = { asdf: 'qwerty' }
          expect { subject.vnp_atchms_create(data) }.to(raise_error do |error|
            expect(error).to be_a(ArgumentError)
            expect(error.message).to eq('Missing required keys: vnp_proc_id, atchms_file_nm, atchms_descp, atchms_txt')
          end)
        end
      end

      describe 'when submitting valid data' do
        context 'with a base64 string' do
          it 'creates a attachment from data' do
            data = {
              vnp_proc_id:,
              atchms_file_nm: 'test.pdf',
              atchms_descp: 'test',
              atchms_txt: 'base64here'
            }
            use_bgs_cassette('happy_path_base64') do
              result = subject.vnp_atchms_create(data)
              expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
            end
          end
        end

        context 'with a file path' do
          it 'creates a attachment from data' do
            data = {
              vnp_proc_id:,
              atchms_file_nm: 'test.pdf',
              atchms_descp: 'test',
              atchms_txt: Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'extras.pdf').to_s
            }
            use_bgs_cassette('happy_path_file') do
              result = subject.vnp_atchms_create(data)
              expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
            end
          end
        end
      end

      context 'when providing an invalid procId' do
        it 'raises an error' do
          data = {
            vnp_proc_id: '1234abc',
            atchms_file_nm: 'test.pdf',
            atchms_descp: 'test',
            atchms_txt: 'base64here'
          }

          use_bgs_cassette('invalid_procId') do
            expect { subject.vnp_atchms_create(data) }.to raise_error(Common::Exceptions::ServiceError)
          end
        end
      end
    end
  end
end
