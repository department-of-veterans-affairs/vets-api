# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require_relative '../../../lib/ivc_champva/monitor'

RSpec.describe 'ivc_champva:send_cva_remediation_emails rake task', type: :task do
  before(:all) do
    load Rails.root.join('modules', 'ivc_champva', 'lib', 'tasks', 'send_cva_remediation_emails.rake')
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['ivc_champva:send_cva_remediation_emails'] }
  let(:notify_client) { instance_double(VaNotify::Service) }
  let(:monitor) { instance_double(IvcChampva::Monitor) }
  let!(:test_records) { [] }

  # Date range for the production issue: Jan 20-21, 2026
  let(:start_date) { Date.new(2026, 1, 20).beginning_of_day }
  let(:end_date) { Date.new(2026, 1, 21).end_of_day }

  before do
    task.reenable
    allow(VaNotify::Service).to receive(:new).and_return(notify_client)
    allow(notify_client).to receive(:send_email)
    allow(IvcChampva::Monitor).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_missing_status_email_sent)
    allow(monitor).to receive(:log_silent_failure)
  end

  after do
    test_records.each(&:destroy)
    test_records.clear
  end

  describe 'when no affected forms exist' do
    it 'outputs no forms found message' do
      expect { task.invoke }.to output(/No affected forms found/).to_stdout
    end
  end

  describe 'when affected forms exist' do
    before do
      # Single record form (affected) - should be included
      @affected_form = create(:ivc_champva_form,
                              form_number: '10-7959A',
                              created_at: start_date + 1.hour,
                              form_uuid: SecureRandom.uuid,
                              file_name: 'test-uuid-1_10-7959A.pdf',
                              email: "affected-#{SecureRandom.hex(4)}@example.com",
                              email_sent: false,
                              s3_status: 'success')

      # Form with multiple records (not affected) - should be excluded
      @multi_record_uuid = SecureRandom.uuid
      @multi_record_form1 = create(:ivc_champva_form,
                                   form_number: '10-7959A',
                                   created_at: start_date + 2.hours,
                                   form_uuid: @multi_record_uuid,
                                   file_name: 'test-uuid-2_10-7959A.pdf',
                                   email: "multi-#{SecureRandom.hex(4)}@example.com",
                                   email_sent: false,
                                   s3_status: 'success')
      @multi_record_form2 = create(:ivc_champva_form,
                                   form_number: '10-7959A',
                                   created_at: start_date + 2.hours,
                                   form_uuid: @multi_record_uuid,
                                   file_name: 'test-uuid-2_supporting_doc.pdf',
                                   email: "multi-#{SecureRandom.hex(4)}@example.com",
                                   email_sent: false,
                                   s3_status: 'success')

      # Form outside date range - should be excluded
      @outside_range_form = create(:ivc_champva_form,
                                   form_number: '10-7959A',
                                   created_at: Date.new(2026, 1, 19).beginning_of_day,
                                   form_uuid: SecureRandom.uuid,
                                   file_name: 'test-uuid-3_10-7959A.pdf',
                                   email: "outside-#{SecureRandom.hex(4)}@example.com",
                                   email_sent: false,
                                   s3_status: 'success')

      # Different form number - should be excluded
      @different_form = create(:ivc_champva_form,
                               form_number: '10-10D',
                               created_at: start_date + 3.hours,
                               form_uuid: SecureRandom.uuid,
                               file_name: 'test-uuid-4_10-10D.pdf',
                               email: "different-#{SecureRandom.hex(4)}@example.com",
                               email_sent: false,
                               s3_status: 'success')

      test_records.push(@affected_form, @multi_record_form1, @multi_record_form2,
                        @outside_range_form, @different_form)
    end

    it 'finds only forms with single record per form_uuid' do
      output = capture_stdout { task.invoke }
      expect(output).to include('Found 1 affected form records')
      expect(output).to include(@affected_form.form_uuid)
      expect(output).not_to include(@multi_record_uuid)
    end

    it 'sends email to affected form' do
      expect(notify_client).to receive(:send_email).with(
        email_address: @affected_form.email,
        template_id: IvcChampva::Email::EMAIL_TEMPLATE_MAP['10-7959A-FAILURE'],
        personalisation: hash_including(
          email: @affected_form.email,
          first_name: @affected_form.first_name,
          form_number: '10-7959A'
        )
      )

      capture_stdout { task.invoke }
    end

    it 'updates email_sent to true after successful send' do
      expect { capture_stdout { task.invoke } }
        .to change { @affected_form.reload.email_sent }.from(false).to(true)
    end

    it 'tracks the email sent via monitor' do
      expect(monitor).to receive(:track_missing_status_email_sent).with('10-7959A')
      capture_stdout { task.invoke }
    end

    it 'outputs success message with correct counts' do
      output = capture_stdout { task.invoke }
      expect(output).to include('Emails sent successfully: 1')
      expect(output).to include('Emails failed: 0')
      expect(output).to include('Skipped (already sent): 0')
    end
  end

  describe 'deduplication by name/email' do
    before do
      # Two forms with the same name/email - should only send one email
      @duplicate_email = "duplicate-#{SecureRandom.hex(4)}@example.com"
      @first_form = create(:ivc_champva_form,
                           form_number: '10-7959A',
                           created_at: start_date + 1.hour,
                           form_uuid: SecureRandom.uuid,
                           file_name: 'test-uuid-1_10-7959A.pdf',
                           first_name: 'John',
                           last_name: 'Doe',
                           email: @duplicate_email,
                           email_sent: false,
                           s3_status: 'success')

      @second_form = create(:ivc_champva_form,
                            form_number: '10-7959A',
                            created_at: start_date + 2.hours,
                            form_uuid: SecureRandom.uuid,
                            file_name: 'test-uuid-2_10-7959A.pdf',
                            first_name: 'John',
                            last_name: 'Doe',
                            email: @duplicate_email,
                            email_sent: false,
                            s3_status: 'success')

      test_records.push(@first_form, @second_form)
    end

    it 'sends only one email for duplicate name/email combos' do
      expect(notify_client).to receive(:send_email).once

      output = capture_stdout { task.invoke }
      expect(output).to include('Found 2 affected form records')
      expect(output).to include('Deduplicated to 1 unique recipients')
      expect(output).to include('Emails sent successfully: 1')
    end
  end

  describe 'when email sending fails' do
    before do
      @failing_form = create(:ivc_champva_form,
                             form_number: '10-7959A',
                             created_at: start_date + 1.hour,
                             form_uuid: SecureRandom.uuid,
                             file_name: 'test-uuid-1_10-7959A.pdf',
                             email: "fail-#{SecureRandom.hex(4)}@example.com",
                             email_sent: false,
                             s3_status: 'success')
      test_records.push(@failing_form)

      allow(notify_client).to receive(:send_email).and_raise(StandardError, 'VANotify error')
    end

    it 'does not update email_sent on failure' do
      expect { capture_stdout { task.invoke } }
        .not_to(change { @failing_form.reload.email_sent })
    end

    it 'logs silent failure via monitor' do
      expect(monitor).to receive(:log_silent_failure).with(
        hash_including(form_id: '10-7959A', form_uuid: @failing_form.form_uuid)
      )
      capture_stdout { task.invoke }
    end

    it 'outputs failure message with correct counts' do
      output = capture_stdout { task.invoke }
      expect(output).to include('Failed to send email')
      expect(output).to include('VANotify error')
      expect(output).to include('Emails failed: 1')
      expect(output).to include('Emails sent successfully: 0')
    end
  end

  describe 'rate limiting' do
    before do
      # Create 16 affected forms to trigger rate limiting
      16.times do |i|
        form = create(:ivc_champva_form,
                      form_number: '10-7959A',
                      created_at: start_date + i.hours,
                      form_uuid: SecureRandom.uuid,
                      file_name: "test-uuid-#{i}_10-7959A.pdf",
                      email: "rate-limit-#{i}-#{SecureRandom.hex(4)}@example.com",
                      email_sent: false,
                      s3_status: 'success')
        test_records.push(form)
      end
    end

    it 'sleeps after every 15 emails' do
      allow_any_instance_of(Object).to receive(:sleep)

      output = capture_stdout { task.invoke }
      expect(output).to include('Rate limiting - sleeping 1 second...')
    end
  end

  describe 'dry run mode' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DRY_RUN').and_return('true')
      allow(ENV).to receive(:[]).with('PAGE_SIZE').and_return(nil)
      allow(ENV).to receive(:[]).with('PAGE').and_return(nil)
      @dry_run_form = create(:ivc_champva_form,
                             form_number: '10-7959A',
                             created_at: start_date + 1.hour,
                             form_uuid: SecureRandom.uuid,
                             file_name: 'test-uuid-1_10-7959A.pdf',
                             email: "dryrun-#{SecureRandom.hex(4)}@example.com",
                             email_sent: false,
                             s3_status: 'success')
      test_records.push(@dry_run_form)
    end

    it 'does not send emails' do
      expect(notify_client).not_to receive(:send_email)
      capture_stdout { task.invoke }
    end

    it 'does not update email_sent' do
      expect { capture_stdout { task.invoke } }
        .not_to(change { @dry_run_form.reload.email_sent })
    end

    it 'outputs dry run messages' do
      output = capture_stdout { task.invoke }
      expect(output).to include('[DRY RUN MODE')
      expect(output).to include('[DRY RUN] Would send email')
      expect(output).to include('DRY RUN COMPLETE')
      expect(output).to include('Emails that would be sent: 1')
    end
  end

  describe 'pagination' do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DRY_RUN').and_return(nil)
      # Create 6 affected forms
      6.times do |i|
        form = create(:ivc_champva_form,
                      form_number: '10-7959A',
                      created_at: start_date + i.hours,
                      form_uuid: SecureRandom.uuid,
                      file_name: "test-uuid-#{i}_10-7959A.pdf",
                      email: "pagination-#{i}-#{SecureRandom.hex(4)}@example.com",
                      email_sent: false,
                      s3_status: 'success')
        test_records.push(form)
      end
    end

    context 'with PAGE_SIZE=3 and PAGE=0' do
      before do
        allow(ENV).to receive(:[]).with('PAGE_SIZE').and_return('3')
        allow(ENV).to receive(:[]).with('PAGE').and_return('0')
      end

      it 'processes only the first page of records' do
        expect(notify_client).to receive(:send_email).exactly(3).times

        output = capture_stdout { task.invoke }
        expect(output).to include('[PAGE: 0, PAGE_SIZE: 3]')
        expect(output).to include('Total matching form_uuids: 6 (2 pages of 3)')
        expect(output).to include('Emails sent successfully: 3')
        expect(output).to include('Page 0 of 1')
        expect(output).to include('Next page: PAGE=1 PAGE_SIZE=3')
      end
    end

    context 'with PAGE_SIZE=3 and PAGE=1' do
      before do
        allow(ENV).to receive(:[]).with('PAGE_SIZE').and_return('3')
        allow(ENV).to receive(:[]).with('PAGE').and_return('1')
      end

      it 'processes the second page of records' do
        expect(notify_client).to receive(:send_email).exactly(3).times

        output = capture_stdout { task.invoke }
        expect(output).to include('[PAGE: 1, PAGE_SIZE: 3]')
        expect(output).to include('Emails sent successfully: 3')
        expect(output).to include('Page 1 of 1')
        expect(output).not_to include('Next page:')
      end
    end

    context 'with PAGE beyond available records' do
      before do
        allow(ENV).to receive(:[]).with('PAGE_SIZE').and_return('3')
        allow(ENV).to receive(:[]).with('PAGE').and_return('5')
      end

      it 'outputs no records on page message' do
        expect(notify_client).not_to receive(:send_email)

        output = capture_stdout { task.invoke }
        expect(output).to include('No records on page 5')
        expect(output).to include('Valid pages: 0 to 1')
      end
    end

    context 'with default pagination' do
      before do
        allow(ENV).to receive(:[]).with('PAGE_SIZE').and_return(nil)
        allow(ENV).to receive(:[]).with('PAGE').and_return(nil)
      end

      it 'uses default page size of 50 and page 0' do
        expect(notify_client).to receive(:send_email).exactly(6).times

        output = capture_stdout { task.invoke }
        expect(output).to include('[PAGE: 0, PAGE_SIZE: 50]')
        expect(output).to include('Emails sent successfully: 6')
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
