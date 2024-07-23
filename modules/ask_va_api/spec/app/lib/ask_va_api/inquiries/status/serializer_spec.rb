# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module Inquiries
    module Status
      RSpec.describe Serializer do
        let(:info) do
          {
            Status: 'Reopened',
            Message: nil,
            ExceptionOccurred: false,
            ExceptionMessage: nil,
            MessageId: 'c6252e77-cf7f-48b6-96be-1b43d8e9905c'
          }
        end
        let(:status) { AskVAApi::Inquiries::Status::Entity.new(info) }
        let(:response) { described_class.new(status) }
        let(:expected_response) do
          { data: { id: nil,
                    type: :inquiry_status,
                    attributes: {
                      status: info[:Status]
                    } } }
        end

        context 'when successful' do
          it 'returns a json hash' do
            expect(response.serializable_hash).to include(expected_response)
          end
        end
      end
    end
  end
end
