# frozen_string_literal: true

require 'rails_helper'

require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission

RSpec.describe Sidekiq::Form526BackupSubmissionProcess::Submit, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  describe '.perform_async, disabled' do
    # Make sure it doesnt do anything if flipper disabled
    before do
      allow(Settings.form526_backup).to receive(:enabled).and_return(false)
    end

    let!(:submission) { create :form526_submission, :with_everything }

    it 'creates a submission job' do
      expect { subject.perform_async(submission.id) }.to change(subject.jobs, :size).by(1)
    end

    it 'does not create an additional Form526JobStatus record (meaning it returned right away)' do
      expect { subject.perform_async(submission.id) }.to change(Form526JobStatus.all.count, :size).by(0)
    end
  end

  %w[single multi].each do |payload_method|
    describe ".perform_async, enabled, #{payload_method} payload" do
      before do
        allow(Settings.form526_backup).to receive(:submission_method).and_return(payload_method)
        allow(Settings.form526_backup).to receive(:enabled).and_return(true)
      end

      let!(:submission) { create :form526_submission, :with_everything }
      let!(:upload_data) { submission.form[Form526Submission::FORM_526_UPLOADS] }

      context 'successfully' do
        before do
          upload_data.each do |ud|
            file = Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf')
            sea = SupportingEvidenceAttachment.find_or_create_by(guid: ud['confirmationCode'])
            sea.set_file_data!(file)
            sea.save!
          end
        end

        it 'creates a job for submission' do
          expect { subject.perform_async(submission.id) }.to change(subject.jobs, :size).by(1)
        end

        it 'submits' do
          VCR.use_cassette('form526_backup/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('form526_backup/200_evss_get_pdf') do
              VCR.use_cassette('form526_backup/200_lighthouse_intake_upload') do
                jid = subject.perform_async(submission.id)
                last = subject.jobs.last
                jid_from_jobs = last['jid']
                expect(jid).to eq(jid_from_jobs)
                described_class.drain
                expect(jid).not_to be_empty
                job_status = Form526JobStatus.last
                expect(job_status.form526_submission_id).to eq(submission.id)
                expect(job_status.job_class).to eq('BackupSubmission')
                expect(job_status.job_id).to eq(jid)
                expect(job_status.status).to eq('success')
                submission = Form526Submission.last
                expect(submission.backup_submitted_claim_id).not_to be(nil)
              end
            end
          end
        end
      end

      context 'with a submission timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'raises a gateway timeout error' do
          jid = subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
          job_status = Form526JobStatus.find_by(job_id: jid)
          expect(job_status.form526_submission_id).to eq(submission.id)
          expect(job_status.job_class).to eq('BackupSubmission')
          expect(job_status.job_id).to eq(jid)
          expect(job_status.status).to eq('exhausted')
          error = job_status.bgjob_errors
          expect(error.first.last['error_class']).to eq('Common::Exceptions::GatewayTimeout')
          expect(error.first.last['error_message']).to eq('Gateway timeout')
        end
      end

      context 'with an unexpected error' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
        end

        it 'raises a standard error' do
          jid = subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(StandardError)
          job_status = Form526JobStatus.find_by(job_id: jid)
          expect(job_status.form526_submission_id).to eq(submission.id)
          expect(job_status.job_class).to eq('BackupSubmission')
          expect(job_status.job_id).to eq(jid)
          expect(job_status.status).to eq('exhausted')
          error = job_status.bgjob_errors
          expect(error.first.last['error_class']).to eq('StandardError')
          expect(error.first.last['error_message']).to eq('foo')
        end
      end
    end
  end

  describe '.perform_async, enabled, and converts non-pdf evidence to pdf' do
    before do
      allow(Settings.form526_backup).to receive(:submission_method).and_return('single')
      allow(Settings.form526_backup).to receive(:enabled).and_return(true)
    end

    let!(:submission) { create :form526_submission, :with_non_pdf_uploads }
    let!(:upload_data) { submission.form[Form526Submission::FORM_526_UPLOADS] }

    context 'converts non-pdf files to pdf' do
      before do
        upload_data.each do |ud|
          filename = ud['name']
          file = Rack::Test::UploadedFile.new("spec/fixtures/files/#{filename}",
                                              "application/#{File.basename(filename)}")
          sea = SupportingEvidenceAttachment.find_or_create_by(guid: ud['confirmationCode'])
          sea.set_file_data!(file)
          sea.save!
        end
      end

      it 'converts and submits' do
        VCR.use_cassette('form526_backup/200_lighthouse_intake_upload_location') do
          VCR.use_cassette('form526_backup/200_evss_get_pdf') do
            VCR.use_cassette('form526_backup/200_lighthouse_intake_upload') do
              jid = subject.perform_async(submission.id)
              last = subject.jobs.last
              jid_from_jobs = last['jid']
              expect(jid).to eq(jid_from_jobs)
              described_class.drain
              expect(jid).not_to be_empty
              job_status = Form526JobStatus.last
              expect(job_status.form526_submission_id).to eq(submission.id)
              expect(job_status.job_class).to eq('BackupSubmission')
              expect(job_status.job_id).to eq(jid)
              expect(job_status.status).to eq('success')
              submission = Form526Submission.last
              expect(submission.backup_submitted_claim_id).not_to be(nil)
            end
          end
        end
      end
    end
  end
end
