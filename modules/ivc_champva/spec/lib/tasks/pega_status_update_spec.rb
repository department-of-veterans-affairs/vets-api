# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'ivc_champva:pega_status_update rake tasks', type: :task do
  before(:all) do
    load Rails.root.join('modules', 'ivc_champva', 'lib', 'tasks', 'update_pega_status.rake')
    load Rails.root.join('modules', 'ivc_champva', 'lib', 'tasks', 'get_missing_statuses.rake')
    Rake::Task.define_task(:environment)
  end

  let(:cleanup_util) { IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new }
  let!(:test_records) { [] }

  before do
    # Create 4 test records with different scenarios
    @record1 = create(:ivc_champva_form,
                      pega_status: nil,
                      created_at: 1.hour.ago,
                      form_uuid: SecureRandom.uuid,
                      file_name: 'test-uuid-1_10-7959A.pdf',
                      email: "test1-#{SecureRandom.hex(4)}@example.com",
                      s3_status: 'success')

    @record2 = create(:ivc_champva_form,
                      pega_status: nil,
                      created_at: 2.hours.ago,
                      form_uuid: SecureRandom.uuid,
                      file_name: 'test-uuid-2_10-7959A.pdf',
                      email: "test2-#{SecureRandom.hex(4)}@example.com",
                      s3_status: 'success')

    # Record with existing status (should be skipped)
    @record3 = create(:ivc_champva_form,
                      pega_status: 'Processed',
                      created_at: 1.hour.ago,
                      form_uuid: SecureRandom.uuid,
                      file_name: 'test-uuid-3_10-7959A.pdf',
                      email: "test3-#{SecureRandom.hex(4)}@example.com",
                      s3_status: 'success')

    # Record created "now" (should be ignored by missing status cleanup)
    @record4 = create(:ivc_champva_form,
                      pega_status: nil,
                      created_at: Time.current,
                      form_uuid: SecureRandom.uuid,
                      file_name: 'test-uuid-4_10-7959A.pdf',
                      email: "test4-#{SecureRandom.hex(4)}@example.com",
                      s3_status: 'success')

    test_records.push(@record1, @record2, @record3, @record4)
  end

  after do
    # Clean up test records
    test_records.each(&:destroy)
    test_records.clear
  end

  describe 'ivc_champva:get_missing_statuses' do
    let(:task) { Rake::Task['ivc_champva:get_missing_statuses'] }

    before do
      task.reenable
    end

    context 'when SILENT=false (default)' do
      it 'returns only records with nil pega_status older than 1 minute' do
        expect { task.invoke }.to output(/Found 2 forms with missing pega_status/).to_stdout
      end

      it 'displays the formatted table with correct records' do
        output = capture_stdout { task.invoke }
        expect(output).to include('FORM_UUID')
        expect(output).to include('S3_STATUS')
        expect(output).to include('CREATED_AT')
        expect(output).to include('FORM_COUNT')
        expect(output).to include(@record1.form_uuid)
        expect(output).to include(@record2.form_uuid)
        expect(output).to include('success')
        expect(output).to include(@record1.created_at.strftime('%Y-%m-%d %H:%M:%S UTC'))
      end

      it 'does not include records with existing pega_status' do
        expect { task.invoke }.not_to output(/#{@record3.form_uuid}/).to_stdout
      end

      it 'does not include records created within the last minute' do
        expect { task.invoke }.not_to output(/#{@record4.form_uuid}/).to_stdout
      end

      it 'outputs comma-separated UUIDs at the end' do
        output = capture_stdout { task.invoke }
        lines = output.split("\n")
        last_line = lines.last
        output_uuids = last_line.split(',')
        expected_uuids = [@record1.form_uuid, @record2.form_uuid]
        expect(output_uuids).to match_array(expected_uuids)
      end
    end

    context 'when SILENT=true' do
      before do
        ENV['SILENT'] = 'true'
      end

      after do
        ENV.delete('SILENT')
      end

      it 'outputs only the comma-separated UUIDs' do
        output = capture_stdout { task.invoke }
        expect(output.strip).to include(@record1.form_uuid)
        expect(output.strip).to include(@record2.form_uuid)
      end

      it 'does not output any headers or formatting' do
        output = capture_stdout { task.invoke }
        expect(output).not_to include('IVC CHAMPVA GET MISSING PEGA STATUS UUIDs')
        expect(output).not_to include('Found')
        expect(output).not_to include('FORM_UUID')
      end
    end

    context 'when no missing statuses found' do
      before do
        # Update all test records to have a status
        [@record1, @record2].each { |r| r.update!(pega_status: 'Processed') }
      end

      it 'outputs no forms found message' do
        expect { task.invoke }.to output(/No forms found/).to_stdout
      end

      it 'returns early without outputting UUIDs' do
        output = capture_stdout { task.invoke }
        expect(output).not_to include(@record1.form_uuid)
        expect(output).not_to include(@record2.form_uuid)
      end
    end
  end

  describe 'ivc_champva:update_pega_status' do
    let(:task) { Rake::Task['ivc_champva:update_pega_status'] }

    before do
      task.reenable
    end

    context 'with valid FORM_UUIDS' do
      before do
        ENV['FORM_UUIDS'] = "#{@record1.form_uuid},#{@record2.form_uuid},#{@record3.form_uuid}"
      end

      after do
        ENV.delete('FORM_UUIDS')
      end

      context 'when DRY_RUN=false (default)' do
        before do
          task.reenable
        end

        it 'updates only records with nil pega_status' do
          expect { task.invoke }.to change { @record1.reload.pega_status }.from(nil).to('Manually Processed')
          expect(@record2.reload.pega_status).to eq('Manually Processed')
        end

        it 'skips records that already have a pega_status' do
          expect { task.invoke }.not_to(change { @record3.reload.pega_status })
          expect(@record3.reload.pega_status).to eq('Processed')

          # Record created "now" (should be ignored by missing status cleanup)
          expect { task.invoke }.not_to(change { @record4.reload.pega_status })
        end

        it 'outputs skip messages for records with existing status' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/SKIPPED form ID #{@record3.id}.*already has status 'Processed'/)
        end

        it 'outputs update messages for records that were updated' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/Updated form ID #{@record1.id}.*from 'nil' to 'Manually Processed'/)
          expect(output).to match(/Updated form ID #{@record2.id}.*from 'nil' to 'Manually Processed'/)
        end

        it 'shows correct summary counts' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/Total forms updated: 2/)
          expect(output).to match(/Total forms found: 3/)
        end
      end

      context 'when DRY_RUN=true' do
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with('DRY_RUN').and_return('true')
          task.reenable
        end

        after do
          ENV.delete('DRY_RUN')
        end

        it 'does not modify any records' do
          expect { task.invoke }.not_to(change { @record1.reload.pega_status })
          expect(@record2.reload.pega_status).to be_nil
          expect(@record3.reload.pega_status).to eq('Processed')
        end

        it 'outputs dry run messages' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/\[DRY RUN\] Would update form ID #{@record1.id}/)
          expect(output).to match(/\[DRY RUN\] Would update form ID #{@record2.id}/)
        end

        it 'still shows skip messages for records with existing status' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/SKIPPED form ID #{@record3.id}.*already has status 'Processed'/)
        end

        it 'shows dry run in summary' do
          output = capture_stdout { task.invoke }
          expect(output).to match(/Total forms that would be updated: 2/)
          expect(output).to match(/Task completed \(DRY RUN\)!/)
        end
      end
    end

    context 'with mixed status scenario' do
      before do
        # Update one of the nil status records to have a status before running
        @record2.update!(pega_status: 'Manually Processed')
        ENV['FORM_UUIDS'] = "#{@record1.form_uuid},#{@record2.form_uuid}"
        task.reenable
      end

      after do
        ENV.delete('FORM_UUIDS')
      end

      it 'updates only the record that still has nil status' do
        expect { task.invoke }.to change { @record1.reload.pega_status }.from(nil).to('Manually Processed')
        expect(@record2.reload.pega_status).to eq('Manually Processed') # unchanged
      end

      it 'skips the record that was already processed' do
        expect do
          task.invoke
        end.to output(/SKIPPED form ID #{@record2.id}.*already has status 'Manually Processed'/).to_stdout
      end

      it 'shows correct counts for mixed scenario' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/Total forms updated: 1/)
        expect(output).to match(/Total forms found: 2/)
      end
    end

    context 'with invalid input' do
      before do
        task.reenable
      end

      it 'raises error when FORM_UUIDS is empty' do
        ENV['FORM_UUIDS'] = ''
        expect { task.invoke }.to raise_error('FORM_UUIDS required - provide comma-separated list')
        ENV.delete('FORM_UUIDS')
      end

      it 'raises error when FORM_UUIDS is not provided' do
        task.reenable # Need to re-enable after first test
        expect { task.invoke }.to raise_error('FORM_UUIDS required - provide comma-separated list')
      end
    end

    context 'with non-existent UUIDs' do
      before do
        ENV['FORM_UUIDS'] = 'non-existent-uuid'
        task.reenable
      end

      after do
        ENV.delete('FORM_UUIDS')
      end

      it 'handles non-existent UUIDs gracefully' do
        output = capture_stdout { task.invoke }
        expect(output).to match(/WARNING: No forms found for UUID: non-existent-uuid/)
        expect(output).to match(/Failed UUIDs: 1/)
        expect(output).to match(/non-existent-uuid: No forms found/)
      end
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
