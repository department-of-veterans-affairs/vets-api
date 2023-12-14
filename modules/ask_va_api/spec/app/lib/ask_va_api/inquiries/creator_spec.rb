# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskVAApi::Inquiries::Creator do
  let(:icn) { '123456' }
  let(:service) { instance_double(Crm::Service) }
  let(:creator) { described_class.new(icn:, service:) }
  let(:params) { { first_name: 'Fake', last_name: 'Smith' } }
  let(:endpoint) { AskVAApi::Inquiries::Creator::ENDPOINT }

  describe '#initialize' do
    context 'when service is provided' do
      it 'uses the provided service' do
        expect(creator.service).to eq(service)
      end
    end

    context 'when service is not provided' do
      let(:creator) { described_class.new(icn:) }

      it 'sets a default service' do
        expect(creator.service).to be_a(Crm::Service)
      end
    end
  end

  describe '#call' do
    context 'when the API call is successful' do
      before do
        allow(service).to receive(:call).with(endpoint:, method: :post,
                                              payload: { params: }).and_return({ message: 'Inquiry has been created',
                                                                                 status: :ok })
      end

      it 'posts data to the service and returns the response' do
        expect(creator.call(params:)).to eq({ message: 'Inquiry has been created', status: :ok })
      end
    end

    context 'when the API call fails' do
      before do
        allow(service).to receive(:call).and_raise(StandardError)
        allow(ErrorHandler).to receive(:handle_service_error)
      end

      it 'rescues the error and calls ErrorHandler' do
        expect { creator.call(params:) }.not_to raise_error
        expect(ErrorHandler).to have_received(:handle_service_error).with(instance_of(StandardError))
      end
    end
  end
end
