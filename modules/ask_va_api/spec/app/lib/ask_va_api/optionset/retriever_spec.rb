# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Optionset
    RSpec.describe Retriever do
      let(:entity_class) { Entity }
      let(:name) { 'branchofservice' }
      let(:cache_data_service) { instance_double(Crm::CacheData) }

      describe '#call' do
        context 'with user_mock_data' do
          let(:retriever) { described_class.new(name:, user_mock_data: true, entity_class:) }

          it 'reads from file' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'with no user_mock_data' do
          let(:retriever) { described_class.new(name:, user_mock_data: false, entity_class:) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
            allow(cache_data_service).to receive(:call).and_return({ Data: [{ Id: 722_310_000,
                                                                              Name: 'Air Force' }] })
          end

          it 'calls on Crm::CacheData' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end

        context 'when an error occur' do
          let(:retriever) { described_class.new(name: 'branchofservic', user_mock_data: false, entity_class:) }
          let(:body) do
            '{"Data":null,"Message":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
              ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
              ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
              ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","ExceptionOccurred":' \
              'true,"ExceptionMessage":"Data Validation: Invalid OptionSet Name iris_branchofservic, valid' \
              ' values are iris_inquiryabout, iris_inquirysource, iris_inquirytype, iris_levelofauthentication,' \
              ' iris_suffix, iris_veteranrelationship, iris_branchofservice, iris_country, iris_province,' \
              ' iris_responsetype, iris_dependentrelationship, statuscode, iris_messagetype","MessageId":' \
              '"6dfa81bd-f04a-4f39-88c5-1422d88ed3ff"}'
          end
          let(:failure) { Faraday::Response.new(response_body: body, status: 400) }

          before do
            allow_any_instance_of(Crm::CrmToken).to receive(:call).and_return('token')
            allow_any_instance_of(Crm::Service).to receive(:call)
              .with(endpoint: 'optionset', payload: { name: 'iris_branchofservic' }).and_return(failure)
          end

          it 'raise the error' do
            expect { retriever.call }.to raise_error(ErrorHandler::ServiceError)
          end
        end
      end
    end
  end
end
