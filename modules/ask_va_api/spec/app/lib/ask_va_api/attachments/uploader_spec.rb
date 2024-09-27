# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Attachments
    RSpec.describe Uploader do
      subject { described_class.new(params).call }

      let(:file) { double('File', size: 10.megabytes, content_type: 'application/pdf') }
      let(:inquiryId) { '1c1f5631-9edf-ee11-904d-001dd8306b36' }
      let(:correspondenceId) { nil }
      let(:params) do
        {
          fileName: 'testfile',
          fileContent: file,
          inquiryId:,
          correspondenceId:
        }
      end

      describe '#call' do
        context 'when successful' do
          let(:response) do
            { Data: {
              Id: '1c1f5631-9edf-ee11-904d-001dd8306b36'
            } }
          end

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Crm::Service).to receive(:call)
              .with(endpoint: 'attachment/new', payload: {
                      inquiryId:,
                      fileName: params[:fileName],
                      fileContent: file,
                      correspondenceId: params[:correspondenceId]
                    }).and_return(response)
          end

          it 'returns the Id' do
            expect(subject).to eq({ Id: '1c1f5631-9edf-ee11-904d-001dd8306b36' })
          end
        end

        context 'when not successful' do
          let(:body) do
            '{"Data":null,"Message":"Data Validation: No Inquiries found"' \
              ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: No Inquiries found' \
              '","MessageId":"ca5b990a-63fe-407d-a364-46caffce12c1"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Crm::Service).to receive(:call)
              .with(endpoint: 'attachment/new', payload: {
                      inquiryId:,
                      fileName: params[:fileName],
                      fileContent: file,
                      correspondenceId: params[:correspondenceId]
                    }).and_return(failure)
          end

          context 'CRM response with a 400' do
            it 'raise an error' do
              expect { subject }.to raise_error(AttachmentsUploaderError)
            end
          end

          context 'when no file is attached' do
            let(:file) { nil }

            it 'raise an error' do
              expect { subject }.to raise_error(AttachmentsUploaderError, 'Missing file content')
            end
          end

          context 'when the file size exceeds the limit' do
            let(:file) { double('File', size: 30.megabytes, content_type: 'application/pdf') }

            it 'raise an error' do
              expect { subject }.to raise_error(AttachmentsUploaderError,
                                                'File size exceeds the maximum limit of 25 MB')
            end
          end
        end
      end
    end
  end
end
