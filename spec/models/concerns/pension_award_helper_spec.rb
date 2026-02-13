# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionAwardHelper, type: :model do
  # Create a test class that includes the concern but doesn't implement the abstract methods
  let(:test_class_without_methods) do
    Class.new do
      include PensionAwardHelper
    end
  end

  # Create a test class that includes the concern and implements the abstract methods
  let(:test_class_with_methods) do
    Class.new do
      include PensionAwardHelper

      def pension_award_service
        @pension_award_service ||= BID::Awards::Service.new(nil)
      end

      def track_pension_award_error(error)
        Rails.logger.warn("Test error: #{error.message}")
      end
    end
  end

  let(:incomplete_instance) { test_class_without_methods.new }
  let(:complete_instance) { test_class_with_methods.new }

  describe 'abstract method validation' do
    describe '#pension_award_service' do
      it 'raises NotImplementedError when not implemented and awards_pension is called' do
        expect { incomplete_instance.awards_pension }.to raise_error(
          NotImplementedError, 'Including class must implement #pension_award_service'
        )
      end

      it 'does not raise error when implemented' do
        expect { complete_instance.pension_award_service }.not_to raise_error
      end
    end

    describe '#track_pension_award_error' do
      it 'raises NotImplementedError when not implemented and service error occurs' do
        # Create a test class that implements pension_award_service but not track_pension_award_error
        test_class_partial = Class.new do
          include PensionAwardHelper

          def pension_award_service
            service = instance_double(BID::Awards::Service)
            allow(service).to receive(:get_current_awards).and_raise(StandardError.new('service error'))
            service
          end
        end

        instance = test_class_partial.new
        expect { instance.awards_pension }.to raise_error(
          NotImplementedError, 'Including class must implement #track_pension_award_error'
        )
      end

      it 'does not raise error when implemented' do
        error = StandardError.new('test error')
        expect(Rails.logger).to receive(:warn).with('Test error: test error')
        expect { complete_instance.send(:track_pension_award_error, error) }.not_to raise_error
      end
    end
  end

  describe 'pension award functionality' do
    let(:mock_service) { instance_double(BID::Awards::Service) }
    let(:complete_instance) { test_class_with_methods.new }

    before do
      allow(complete_instance).to receive(:pension_award_service).and_return(mock_service)
    end

    describe '#is_in_receipt_of_pension' do
      it 'returns 1 when user is in receipt of pension' do
        allow(complete_instance).to receive(:awards_pension).and_return({ is_in_receipt_of_pension: true })
        expect(complete_instance.is_in_receipt_of_pension).to eq(1)
      end

      it 'returns 0 when user is not in receipt of pension' do
        allow(complete_instance).to receive(:awards_pension).and_return({ is_in_receipt_of_pension: false })
        expect(complete_instance.is_in_receipt_of_pension).to eq(0)
      end

      it 'returns -1 when pension status is unknown' do
        allow(complete_instance).to receive(:awards_pension).and_return({})
        expect(complete_instance.is_in_receipt_of_pension).to eq(-1)
      end
    end

    describe '#net_worth_limit' do
      it 'returns the net worth limit from awards_pension when available' do
        allow(complete_instance).to receive(:awards_pension).and_return({ net_worth_limit: 100_000 })
        expect(complete_instance.net_worth_limit).to eq(100_000)
      end

      it 'returns default value when net worth limit is not available' do
        allow(complete_instance).to receive(:awards_pension).and_return({})
        expect(complete_instance.net_worth_limit).to eq(163_699)
      end
    end

    describe '#awards_pension' do
      let(:mock_response_body) do
        {
          'award' => {
            'award_event_list' => {
              'award_events' => [
                {
                  'award_line_list' => {
                    'award_lines' => [
                      {
                        'award_line_type' => 'IP',
                        'effective_date' => '2020-01-01T00:00:00-05:00'
                      }
                    ]
                  }
                }
              ]
            }
          }
        }
      end

      it 'returns pension status when user has IP award line type' do
        mock_response = OpenStruct.new(body: mock_response_body)
        allow(mock_service).to receive(:get_current_awards).and_return(mock_response)

        result = complete_instance.awards_pension
        expect(result[:is_in_receipt_of_pension]).to be(true)
      end

      it 'returns non-pension status when user has non-IP award line type' do
        mock_response_body['award']['award_event_list']['award_events'][0]['award_line_list']['award_lines'][0]['award_line_type'] = 'COMP' # rubocop:disable Layout/LineLength
        mock_response = OpenStruct.new(body: mock_response_body)
        allow(mock_service).to receive(:get_current_awards).and_return(mock_response)

        result = complete_instance.awards_pension
        expect(result[:is_in_receipt_of_pension]).to be(false)
      end

      it 'returns empty hash when response body is empty' do
        mock_response = OpenStruct.new(body: nil)
        allow(mock_service).to receive(:get_current_awards).and_return(mock_response)

        result = complete_instance.awards_pension
        expect(result).to eq({})
      end

      it 'handles service errors and returns empty hash' do
        error = StandardError.new('Service error')
        allow(mock_service).to receive(:get_current_awards).and_raise(error)
        allow(complete_instance).to receive(:track_pension_award_error)

        result = complete_instance.awards_pension
        expect(result).to eq({})
        expect(complete_instance).to have_received(:track_pension_award_error).with(error)
      end
    end

    describe '#extract_award_lines' do
      let(:current_awards_data) do
        {
          'award' => {
            'award_event_list' => {
              'award_events' => [
                {
                  'award_line_list' => {
                    'award_lines' => [
                      { 'award_line_type' => 'IP' },
                      { 'award_line_type' => 'COMP' }
                    ]
                  }
                },
                {
                  'award_line_list' => {
                    'award_lines' => [
                      { 'award_line_type' => 'OTHER' }
                    ]
                  }
                }
              ]
            }
          }
        }
      end

      it 'extracts all award lines from all events' do
        result = complete_instance.send(:extract_award_lines, current_awards_data)
        expect(result.length).to eq(3)
        expect(result.map { |line| line['award_line_type'] }).to contain_exactly('IP', 'COMP', 'OTHER')
      end

      it 'returns empty array when no award events exist' do
        empty_data = { 'award' => { 'award_event_list' => { 'award_events' => [] } } }
        result = complete_instance.send(:extract_award_lines, empty_data)
        expect(result).to eq([])
      end
    end

    describe '#find_latest_effective_award_line' do
      let(:award_lines) do
        [
          { 'award_line_type' => 'IP', 'effective_date' => '2020-01-01T00:00:00-05:00' },
          { 'award_line_type' => 'COMP', 'effective_date' => '2021-01-01T00:00:00-05:00' },
          { 'award_line_type' => 'OTHER', 'effective_date' => '2019-01-01T00:00:00-05:00' }
        ]
      end

      it 'returns the latest award line that is prior to today' do
        result = complete_instance.send(:find_latest_effective_award_line, award_lines)
        expect(result['award_line_type']).to eq('COMP')
        expect(result['effective_date']).to eq('2021-01-01T00:00:00-05:00')
      end

      it 'excludes award lines with future effective dates' do
        future_date = (Date.current + 1.year).strftime('%Y-%m-%dT00:00:00-05:00')
        award_lines << { 'award_line_type' => 'FUTURE', 'effective_date' => future_date }

        result = complete_instance.send(:find_latest_effective_award_line, award_lines)
        expect(result['award_line_type']).to eq('COMP')
      end

      it 'returns nil when no lines have effective dates prior to today' do
        future_lines = [
          { 'award_line_type' => 'IP', 'effective_date' => (Date.current + 1.day).strftime('%Y-%m-%dT00:00:00-05:00') }
        ]
        result = complete_instance.send(:find_latest_effective_award_line, future_lines)
        expect(result).to be_nil
      end

      it 'returns nil when award lines array is empty' do
        result = complete_instance.send(:find_latest_effective_award_line, [])
        expect(result).to be_nil
      end
    end
  end
end
