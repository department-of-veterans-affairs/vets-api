# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VirtualAgent::VirtualAgentAppealController, type: :controller do
  # let(:exception) { StandardError.new('Test error') }
  # let(:context) { 'An error occurred while attempting to retrieve the appeal(s)' }

  describe '#service_exception_handler' do
    let(:exception) { StandardError.new('An error occurred') }

    it 'calls service_exception_handler with the exception' do
      allow(Rails.logger).to receive(:error)
      expect(controller).to receive(:service_exception_handler).with(exception)
      expect(Rails.logger).to have_received(:error)
      controller.send(:service_exception_handler, exception)
    end
  end

  # before do
  #   # Simulate a request to ensure the response object is available
  #   # allow(controller).to receive(:head).with(:internal_server_error)

  #   get :index
  # rescue
  #   nil
  # end

  # describe '#service_exception_handler' do
  #   it 'logs the error to Rails logger' do
  #     # expect(Rails.logger).to receive(:error).with(
  #     #   exception.message
  #     # )

  #     controller.send(:service_exception_handler, exception)

  #     expect(Rails.logger).to receive(:error).with(
  #       hash_including(message: a_string_including('Test error'))
  #     )
  #   end

  #   # it 'renders internal server error' do
  #   #   expect(controller).to receive(:head).with(:internal_server_error)

  #   #   controller.send(:service_exception_handler, exception)
  #   # end
  # end
end
