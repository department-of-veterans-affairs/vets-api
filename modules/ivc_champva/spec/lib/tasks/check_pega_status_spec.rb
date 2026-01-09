# frozen_string_literal: true

# rubocop:disable Layout/LineLength
require 'rails_helper'

RSpec.describe 'ivc_champva:check_pega_status', type: :task do
  before(:all) do
    load Rails.root.join('modules', 'ivc_champva', 'lib', 'tasks', 'check_pega_status.rake')
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['ivc_champva:check_pega_status'] }
  let(:pega_api_client) { instance_double(IvcChampva::PegaApi::Client) }

  # Test data setup
  before do
    # Create test records with different scenarios
    @uuid_with_matching_reports = SecureRandom.uuid
    @uuid_with_no_reports = SecureRandom.uuid
    @uuid_with_count_mismatch = SecureRandom.uuid
    @uuid_with_api_error = SecureRandom.uuid
    @nonexistent_uuid = SecureRandom.uuid

    # Records that should have matching Pega reports (2 files, 2 reports)
    @record1 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_matching_reports,
                      file_name: 'matching_file_1.pdf',
                      created_at: 2.hours.ago)
    @record2 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_matching_reports,
                      file_name: 'matching_file_2.pdf',
                      created_at: 2.hours.ago)

    # Record that should have no Pega reports
    @record3 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_no_reports,
                      file_name: 'unprocessed_file.pdf',
                      created_at: 2.hours.ago)

    # Records with count mismatch (3 local files, 2 Pega reports)
    @record4 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_count_mismatch,
                      file_name: 'mismatch_file_1.pdf',
                      created_at: 2.hours.ago)
    @record5 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_count_mismatch,
                      file_name: 'mismatch_file_2.pdf',
                      created_at: 2.hours.ago)
    @record6 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_count_mismatch,
                      file_name: 'mismatch_file_3.pdf',
                      created_at: 2.hours.ago)

    # Record that will cause API error
    @record7 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_api_error,
                      file_name: 'error_file.pdf',
                      created_at: 2.hours.ago)

    # Add a UUID with VES JSON file to test filtering
    @uuid_with_ves_json = SecureRandom.uuid
    @record8 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_ves_json,
                      file_name: 'regular_file.pdf',
                      s3_status: '[200]',
                      created_at: 1.hour.ago)
    @record9 = create(:ivc_champva_form,
                      form_uuid: @uuid_with_ves_json,
                      file_name: "#{@uuid_with_ves_json}_vha_10_10d_ves.json",
                      s3_status: '[200]',
                      created_at: 1.hour.ago)

    # Mock the Pega API client
    allow(IvcChampva::PegaApi::Client).to receive(:new).and_return(pega_api_client)
  end

  after do
    [@record1, @record2, @record3, @record4, @record5, @record6, @record7, @record8, @record9].each(&:destroy)
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe 'with no FORM_UUIDS provided' do
    let(:cleanup_util) { instance_double(IvcChampva::ProdSupportUtilities::MissingStatusCleanup) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FORM_UUIDS').and_return(nil)
      allow(IvcChampva::ProdSupportUtilities::MissingStatusCleanup).to receive(:new).and_return(cleanup_util)
      task.reenable
    end

    context 'when missing statuses are found' do
      before do
        allow(cleanup_util).to receive(:get_missing_statuses).with(silent: true, ignore_last_minute: true).and_return({
                                                                                                                        @uuid_with_matching_reports => [
                                                                                                                          @record1, @record2
                                                                                                                        ],
                                                                                                                        @uuid_with_no_reports => [@record3]
                                                                                                                      })

        # Mock API responses for the auto-detected UUIDs
        allow(pega_api_client).to receive(:record_has_matching_report) do |record|
          case record.form_uuid
          when @uuid_with_matching_reports
            [
              {
                'Creation Date' => '2024-12-03T07:04:20.156000',
                'PEGA Case ID' => 'D-12345',
                'Status' => 'Processed',
                'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
              },
              {
                'Creation Date' => '2024-12-03T07:04:22.210000',
                'PEGA Case ID' => 'D-12346',
                'Status' => 'Processed',
                'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
              }
            ]
          when @uuid_with_no_reports
            false
          end
        end
      end

      it 'automatically retrieves missing UUIDs and processes them' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/No FORM_UUIDS provided - automatically retrieving forms/)
        expect(output).to match(/Found 2 form UUIDs with missing pega_status/)
        expect(output).to match(/Total UUIDs processed: 2/)
      end

      it 'displays auto-detection messages' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/Getting forms with missing pega_status \(ignoring submissions from last minute\)/)
        expect(output).to match(/Found 2 form UUIDs with missing pega_status/)
      end
    end

    context 'when no missing statuses are found' do
      before do
        allow(cleanup_util).to receive(:get_missing_statuses).with(silent: true,
                                                                   ignore_last_minute: true).and_return({})
      end

      it 'completes early with no work message' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/No forms found with missing pega_status/)
        expect(output).to match(/Task completed - nothing to check!/)
        expect(output).not_to match(/SUMMARY REPORT/)
      end
    end
  end

  describe 'with empty FORM_UUIDS' do
    before do
      ENV['FORM_UUIDS'] = '  ,  ,  '
      task.reenable
    end

    after do
      ENV.delete('FORM_UUIDS')
    end

    it 'exits with error message' do
      expect { task.invoke }.to raise_error(RuntimeError, 'No valid form UUIDs provided')
    end

    it 'displays no valid UUIDs message' do
      output = capture_stdout do
        expect { task.invoke }.to raise_error(RuntimeError, 'No valid form UUIDs provided')
      end
      expect(output).to match(/ERROR: No valid form UUIDs provided/)
    end
  end

  describe 'with valid FORM_UUIDS' do
    let(:matching_reports) do
      [
        {
          'Creation Date' => '2024-12-03T07:04:20.156000',
          'PEGA Case ID' => 'D-12345',
          'Status' => 'Processed',
          'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
        },
        {
          'Creation Date' => '2024-12-03T07:04:22.210000',
          'PEGA Case ID' => 'D-12346',
          'Status' => 'Processed',
          'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
        }
      ]
    end

    let(:mismatch_reports) do
      [
        {
          'Creation Date' => '2024-12-03T07:04:20.156000',
          'PEGA Case ID' => 'D-12347',
          'Status' => 'Open',
          'UUID' => "#{@uuid_with_count_mismatch[0...-1]}+"
        },
        {
          'Creation Date' => '2024-12-03T07:04:22.210000',
          'PEGA Case ID' => 'D-12348',
          'Status' => 'Open',
          'UUID' => "#{@uuid_with_count_mismatch[0...-1]}+"
        }
      ]
    end

    before do
      ENV['FORM_UUIDS'] = [
        @uuid_with_matching_reports,
        @uuid_with_no_reports,
        @uuid_with_count_mismatch,
        @uuid_with_api_error,
        @nonexistent_uuid
      ].join(',')

      # Mock API responses
      allow(pega_api_client).to receive(:record_has_matching_report) do |record|
        case record.form_uuid
        when @uuid_with_matching_reports
          matching_reports
        when @uuid_with_no_reports
          false
        when @uuid_with_count_mismatch
          mismatch_reports
        when @uuid_with_api_error
          raise IvcChampva::PegaApi::PegaApiError, 'API connection failed'
        when @uuid_with_ves_json
          # Return 1 report for the PDF file (VES JSON should be excluded from count)
          [
            {
              'Creation Date' => '2024-12-03T07:04:20.156000',
              'PEGA Case ID' => 'CASE-VES-001',
              'Status' => 'Processed',
              'UUID' => "#{@uuid_with_ves_json[0...-1]}+"
            }
          ]
        else
          []
        end
      end

      task.reenable
    end

    after do
      ENV.delete('FORM_UUIDS')
    end

    it 'processes all provided UUIDs' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/Form UUIDs: 5 provided via FORM_UUIDS/)
      expect(output).to match(/Total UUIDs processed: 5/)
    end

    it 'identifies UUIDs with matching Pega reports' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/Found 2 Pega report\(s\)/)
      expect(output).to match(/File counts match \(2 local, 2 Pega\)/)
      expect(output).to match(/UUIDs with matching Pega reports: 1/)
    end

    it 'identifies UUIDs with no Pega reports' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/No Pega reports found for UUID: #{@uuid_with_no_reports}/)
    end

    it 'identifies UUIDs with count mismatches' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/File count mismatch \(3 local, 2 Pega\)/)
    end

    it 'handles API errors gracefully' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/PegaApiError: API connection failed/)
      expect(output).to match(/API errors encountered: 1/)
    end

    it 'handles nonexistent UUIDs' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/No local records found for UUID: #{@nonexistent_uuid}/)
    end

    it 'does not display detailed Pega report information' do
      output = capture_stdout { task.invoke }
      expect(output).not_to match(/Case ID:/)
      expect(output).not_to match(/Status:/)
    end

    it 'generates unprocessed files report' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/UNPROCESSED FILES/)
      expect(output).to match(/FORM_UUID.*FILE_NAME.*S3_STATUS.*CREATED_AT.*ISSUE/)
      expect(output).to match(/#{@uuid_with_no_reports}.*unprocessed_file\.pdf.*NOT_FOUND/)
      expect(output).to match(/#{@uuid_with_count_mismatch}.*mismatch_file_1\.pdf.*COUNT_MISMATCH/)
    end

    it 'generates API errors report' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/API ERRORS/)
      expect(output).to match(/FORM_UUID.*TIMESTAMP.*ERROR/)
      expect(output).to match(/#{@uuid_with_api_error}.*API connection failed/)
    end

    it 'shows correct summary counts' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/Total files checked: 7/)
      expect(output).to match(/UUIDs with unprocessed files: 2/)
    end

    it 'logs API errors to Rails logger' do
      expect(Rails.logger).to receive(:error).with(/PegaApiError for UUID #{@uuid_with_api_error}/)
      capture_stdout { task.invoke }
    end

    it 'outputs fully processed UUIDs for piping to update_pega_status' do
      output = capture_stdout { task.invoke }
      expect(output).to match(/FULLY PROCESSED UUIDs \(ready for status update\)/)
      expect(output).to match(/Found 1 UUIDs with all files processed by Pega/)
      expect(output).to match(/FORM_UUIDS="#{@uuid_with_matching_reports}" rake ivc_champva:update_pega_status/)
      expect(output).to match(/Comma-separated list for FORM_UUIDS variable:/)
      # Check that only the matching UUID is in the final output line
      lines = output.split("\n")
      uuid_line = lines.find { |line| line.match?(/^[0-9a-f-]{36}(,[0-9a-f-]{36})*$/) }
      expect(uuid_line).to eq(@uuid_with_matching_reports)
    end

    it 'excludes VES JSON files from Pega count comparison' do
      # Test with UUID that has both regular PDF and VES JSON file
      ENV['FORM_UUIDS'] = @uuid_with_ves_json

      output = capture_stdout { task.invoke }

      # Should show only Pega-processable records (excluding VES JSON)
      expect(output).to match(/Found 1 local record\(s\)/)
      # Should match counts (1 local Pega file vs 1 Pega report)
      expect(output).to match(/File counts match \(1 local, 1 Pega\)/)
      # Should be marked as fully processed
      expect(output).to match(/Found 1 UUIDs with all files processed by Pega/)
    end
  end

  describe 'with single UUID scenarios' do
    before do
      task.reenable
    end

    after do
      ENV.delete('FORM_UUIDS')
    end

    context 'when UUID has processed files' do
      before do
        ENV['FORM_UUIDS'] = @uuid_with_matching_reports
        allow(pega_api_client).to receive(:record_has_matching_report).and_return([
                                                                                    {
                                                                                      'Creation Date' => '2024-12-03T07:04:20.156000',
                                                                                      'PEGA Case ID' => 'D-99999',
                                                                                      'Status' => 'Resolved-Complete',
                                                                                      'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
                                                                                    },
                                                                                    {
                                                                                      'Creation Date' => '2024-12-03T07:04:22.210000',
                                                                                      'PEGA Case ID' => 'D-99998',
                                                                                      'Status' => 'Resolved-Complete',
                                                                                      'UUID' => "#{@uuid_with_matching_reports[0...-1]}+"
                                                                                    }
                                                                                  ])
      end

      it 'shows successful processing' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/File counts match/)
        expect(output).to match(/UUIDs with matching Pega reports: 1/)
        expect(output).not_to match(/UNPROCESSED FILES/)
      end
    end

    context 'when UUID has unprocessed files' do
      before do
        ENV['FORM_UUIDS'] = @uuid_with_no_reports
        allow(pega_api_client).to receive(:record_has_matching_report).and_return(false)
      end

      it 'shows unprocessed status' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/No Pega reports found/)
        expect(output).to match(/UUIDs with matching Pega reports: 0/)
        expect(output).to match(/UNPROCESSED FILES/)
        expect(output).to match(/NOT_FOUND/)
      end

      it 'shows no fully processed UUIDs message' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/No UUIDs found with all files fully processed by Pega/)
        expect(output).not_to match(/FULLY PROCESSED UUIDs/)
      end
    end

    context 'when API returns empty array' do
      before do
        ENV['FORM_UUIDS'] = @uuid_with_no_reports
        allow(pega_api_client).to receive(:record_has_matching_report).and_return([])
      end

      it 'treats empty array as no reports found' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/No Pega reports found/)
        expect(output).to match(/UNPROCESSED FILES/)
      end
    end
  end

  describe 'error handling' do
    before do
      ENV['FORM_UUIDS'] = @uuid_with_api_error
      task.reenable
    end

    after do
      ENV.delete('FORM_UUIDS')
    end

    context 'when unexpected error occurs' do
      before do
        allow(pega_api_client).to receive(:record_has_matching_report).and_raise(StandardError, 'Unexpected error')
      end

      it 'handles unexpected errors gracefully' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/Unexpected error: Unexpected error/)
        expect(output).to match(/API errors encountered: 1/)
      end

      it 'logs unexpected errors with backtrace' do
        expect(Rails.logger).to receive(:error).with(/Unexpected error for UUID #{@uuid_with_api_error}/)
        expect(Rails.logger).to receive(:error).with(String)
        capture_stdout { task.invoke }
      end
    end
  end
end
# rubocop:enable Layout/LineLength
