# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vass::Logging do
  let(:test_class) do
    Class.new do
      include Vass::Logging

      def self.name
        'Vass::TestService'
      end

      def log_test_event(action:, level: :info, **metadata)
        log_vass_event(action:, level:, **metadata)
      end
    end
  end

  let(:test_instance) { test_class.new }

  describe '#log_vass_event' do
    context 'when called from a service class' do
      it 'logs with service component derived from class name' do
        hash_including(
          service: 'vass',
          action: 'test_action',
          component: 'test_service'
        )

        expect(Rails.logger).to receive(:info).with(a_string_including(
                                                      '"service":"vass"',
                                                      '"action":"test_action"',
                                                      '"component":"test_service"'
                                                    ))

        test_instance.log_test_event(action: 'test_action')
      end

      it 'includes timestamp in ISO8601 format' do
        freeze_time = Time.zone.parse('2026-01-20 12:00:00 UTC')

        Timecop.freeze(freeze_time) do
          expect(Rails.logger).to receive(:info).with(a_string_including(
                                                        '"timestamp":"2026-01-20T12:00:00Z"'
                                                      ))

          test_instance.log_test_event(action: 'test_action')
        end
      end

      it 'includes optional vass_uuid when provided' do
        expect(Rails.logger).to receive(:info).with(a_string_including(
                                                      '"vass_uuid":"test-uuid-123"'
                                                    ))

        test_instance.log_test_event(action: 'test_action', vass_uuid: 'test-uuid-123')
      end

      it 'includes additional metadata' do
        expect(Rails.logger).to receive(:warn).with(a_string_including(
                                                      '"correlation_id":"corr-123"',
                                                      '"error_class":"TestError"'
                                                    ))

        test_instance.log_test_event(
          action: 'test_action',
          level: :warn,
          correlation_id: 'corr-123',
          error_class: 'TestError'
        )
      end
    end

    context 'with different log levels' do
      it 'logs at info level by default' do
        expect(Rails.logger).to receive(:info)
        test_instance.log_test_event(action: 'test_action')
      end

      it 'logs at debug level when specified' do
        expect(Rails.logger).to receive(:debug)
        test_instance.log_test_event(action: 'test_action', level: :debug)
      end

      it 'logs at warn level when specified' do
        expect(Rails.logger).to receive(:warn)
        test_instance.log_test_event(action: 'test_action', level: :warn)
      end

      it 'logs at error level when specified' do
        expect(Rails.logger).to receive(:error)
        test_instance.log_test_event(action: 'test_action', level: :error)
      end

      it 'logs at fatal level when specified' do
        expect(Rails.logger).to receive(:fatal)
        test_instance.log_test_event(action: 'test_action', level: :fatal)
      end

      it 'defaults to info level for invalid level' do
        expect(Rails.logger).to receive(:info)
        test_instance.log_test_event(action: 'test_action', level: :invalid)
      end
    end

    context 'when called from a controller' do
      let(:controller_class) do
        Class.new do
          include Vass::Logging

          def controller_name
            'sessions'
          end

          def log_controller_event
            log_vass_event(action: 'controller_action')
          end
        end
      end

      let(:controller_instance) { controller_class.new }

      it 'uses controller_name instead of component' do
        expect(Rails.logger).to receive(:info).with(a_string_including(
                                                      '"controller":"sessions"'
                                                    ))

        controller_instance.log_controller_event
      end

      it 'does not include component field when controller_name is present' do
        allow(Rails.logger).to receive(:info) do |message|
          expect(message).not_to include('"component"')
        end

        controller_instance.log_controller_event
      end
    end

    context 'JSON output format' do
      it 'outputs valid JSON' do
        json_output = nil
        allow(Rails.logger).to receive(:info) { |message| json_output = message }

        test_instance.log_test_event(action: 'test_action', custom_field: 'value')

        expect { JSON.parse(json_output) }.not_to raise_error
      end

      it 'includes all expected fields in JSON output' do
        json_output = nil
        allow(Rails.logger).to receive(:info) { |message| json_output = message }

        test_instance.log_test_event(
          action: 'test_action',
          vass_uuid: 'uuid-123',
          extra: 'data'
        )

        parsed = JSON.parse(json_output)
        expect(parsed).to include(
          'service' => 'vass',
          'action' => 'test_action',
          'component' => 'test_service',
          'vass_uuid' => 'uuid-123',
          'extra' => 'data'
        )
        expect(parsed).to have_key('timestamp')
      end
    end
  end
end
