# frozen_string_literal: true

require 'rails_helper'

module AccreditedRepresentativePortal
  RSpec.describe ControllerTracking do
    let(:dummy_controller) do
      Class.new do
        include ControllerTracking

        attr_accessor :current_user

        def controller_name
          'arbitrary'
        end

        def action_name
          'arbitrary'
        end

        def initialize(current_user = nil)
          @current_user = current_user
        end
      end
    end

    let(:current_user) { double('RepresentativeUser') }
    let(:logger_instance) { dummy_controller.new(current_user) }
    let(:monitoring_service) { Monitoring::Service.new('accredited-representative-portal', user_context: nil) }

    before do
      allow(logger_instance).to receive(:monitor).and_return(monitoring_service)
      allow(monitoring_service).to receive(:track_request)
      allow(monitoring_service).to receive(:track_error)
      allow(current_user).to receive(:uuid).and_return('anonymous')
    end

    describe '#track_request' do
      it 'logs a request with default message and standard tags' do
        logger_instance.send(:track_request)

        expect(monitoring_service).to have_received(:track_request).with(
          message: nil,
          metric: Monitoring::Metric::POA,
          tags: array_including(
            'operation:arbitrary_arbitrary',
            'source:api',
            'service:accredited-representative-portal'
          )
        )
      end

      it 'logs a request with a custom message and additional tags' do
        logger_instance.send(:track_request, 'Custom Message', tags: ['category:auth'])

        expect(monitoring_service).to have_received(:track_request).with(
          message: 'Custom Message',
          metric: Monitoring::Metric::POA,
          tags: array_including(
            'operation:arbitrary_arbitrary',
            'source:api',
            'service:accredited-representative-portal',
            'category:auth'
          )
        )
      end
    end

    describe '#track_error' do
      let(:error) { StandardError.new('Something went wrong') }

      it 'logs an error with default tags' do
        logger_instance.send(:track_error, message: 'Unexpected error', error: error)

        expect(monitoring_service).to have_received(:track_error).with(
          message: 'Unexpected error',
          metric: Monitoring::Metric::POA,
          error: error,
          tags: array_including(
            'operation:arbitrary_arbitrary',
            'source:api',
            'service:accredited-representative-portal'
          )
        )
      end
    end
  end
end
