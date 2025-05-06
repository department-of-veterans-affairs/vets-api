# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Correspondences
    RSpec.describe Creator do
      subject(:creator) { described_class.new(icn:, params:, inquiry_id: '123', service: nil) }

      let(:params) { { reply: 'this is a corespondence message', files: [{ file_name: nil, file_content: nil }] } }
      let(:icn) { '123' }

      describe '#call' do
        context 'when successful' do
          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service).to receive(:call).and_return({ Data: { Id: '456' } })
          end

          it 'response with a correspondence ID' do
            expect(creator.call).to eq({ Id: '456' })
          end
        end

        context 'when not successful' do
          let(:body) do
            '{"Data":null,"Message":"Data Validation: Missing Reply"' \
              ',"ExceptionOccurred":true,"ExceptionMessage":"Data Validation: ' \
              'Missing Reply","MessageId":"e2cbe041-df91-41f4-8bd2-8b6d9dbb2e38"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('Token')
            allow_any_instance_of(Crm::Service).to receive(:call).and_return(failure)
          end

          it 'raise CorrespondenceCreatorError' do
            expect { creator.call }.to raise_error(ErrorHandler::ServiceError)
          end
        end
      end
    end
  end
end
