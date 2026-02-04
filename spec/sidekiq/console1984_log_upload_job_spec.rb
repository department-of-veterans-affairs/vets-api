# frozen_string_literal: true

require 'rails_helper'
require 'common/s3_helpers'

RSpec.describe Console1984LogUploadJob, type: :job do
  subject(:job) { described_class.new }

  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  let(:mock_s3_resource) { instance_double(Aws::S3::Resource) }
  let(:yesterday_date) { Date.new(2024, 1, 19) }
  let(:temp_dir) { Rails.root.join('tmp', 'console_access_logs') }
  let(:expected_filename) { "console1984_logs_#{yesterday_date}.json" }
  let(:expected_file_path) { temp_dir.join(expected_filename) }
  let!(:user) { create(:console1984_user, username: 'test.person@va.gov') }

  before do
    FileUtils.mkdir_p(temp_dir)

    allow(Date).to receive(:yesterday).and_return(yesterday_date)

    allow(Aws::S3::Client).to receive(:new).with(region: 'us-gov-west-1').and_return(mock_s3_client)
    allow(Aws::S3::Resource).to receive(:new).with(client: mock_s3_client).and_return(mock_s3_resource)
  end

  after do
    FileUtils.rm_f(expected_file_path.to_s)
  end

  def file_content
    JSON.parse(File.read(expected_file_path))
  end

  describe '#perform' do
    context 'when in a valid environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(Common::S3Helpers).to receive(:upload_file)
        allow(FileUtils).to receive(:rm_f).with(expected_file_path.to_s)
      end

      context 'with console sessions from yesterday' do
        let!(:user) { create(:console1984_user, username: 'john.doe') }
        let!(:session) do
          create(:console1984_session,
                 user:,
                 reason: 'Investigating issue #1234',
                 created_at: yesterday_date.beginning_of_day + 2.hours,
                 updated_at: yesterday_date.beginning_of_day + 3.hours)
        end
        let!(:command_without_sensitive) do
          create(:console1984_command,
                 session:,
                 statements: 'User.count',
                 created_at: yesterday_date.beginning_of_day + 2.hours + 5.minutes)
        end
        let!(:sensitive_access) do
          create(:console1984_sensitive_access,
                 session:,
                 justification: 'Verifying user account status')
        end
        let!(:command_with_sensitive) do
          create(:console1984_command,
                 session:,
                 statements: 'User.find([REDACTED]).email',
                 sensitive_access:,
                 created_at: yesterday_date.beginning_of_day + 2.hours + 10.minutes)
        end

        it 'creates a log file with correct data structure' do
          job.perform

          expect(File.exist?(expected_file_path)).to be true
          expect(file_content).to be_an(Array)
          expect(file_content.length).to eq(1)

          session_data = file_content.first
          expect(session_data).to include(
            'session_id' => session.id,
            'reason' => 'Investigating issue #1234'
          )
          expect(session_data['user']).to include(
            'id' => user.id,
            'username' => 'john.doe'
          )
          expect(session_data['commands'].length).to eq(2)
        end

        it 'correctly formats non-sensitive commands' do
          job.perform

          non_sensitive_cmd = file_content.first['commands'].first

          expect(non_sensitive_cmd).to include(
            'id' => command_without_sensitive.id,
            'statements' => 'User.count',
            'sensitive' => false,
            'sensitive_access' => nil
          )
        end

        it 'correctly formats sensitive commands' do
          job.perform

          file_content = JSON.parse(File.read(expected_file_path))
          sensitive_cmd = file_content.first['commands'].last

          expect(sensitive_cmd).to include(
            'id' => command_with_sensitive.id,
            'statements' => 'User.find([REDACTED]).email',
            'sensitive' => true
          )
          expect(sensitive_cmd['sensitive_access']).to include(
            'id' => sensitive_access.id,
            'justification' => 'Verifying user account status'
          )
        end

        it 'uploads the file to S3 with correct parameters' do
          expect(Common::S3Helpers).to receive(:upload_file).with(
            s3_resource: mock_s3_resource,
            bucket: 'vets-api-console-access-logs',
            key: "test/#{expected_filename}",
            file_path: expected_file_path.to_s,
            content_type: 'application/json',
            server_side_encryption: 'AES256'
          )

          job.perform
        end
      end

      context 'with no sessions from yesterday' do
        it 'creates an empty array JSON file' do
          job.perform

          file_content = JSON.parse(File.read(expected_file_path))
          expect(file_content).to eq([])
        end

        it 'still uploads the empty file to S3' do
          expect(Common::S3Helpers).to receive(:upload_file).with(
            s3_resource: mock_s3_resource,
            bucket: 'vets-api-console-access-logs',
            file_path: expected_file_path.to_s,
            key: "test/#{expected_filename}",
            content_type: 'application/json',
            server_side_encryption: 'AES256'
          )

          job.perform
        end
      end

      context 'with sessions from different days' do
        let!(:user) { create(:console1984_user) }
        let!(:yesterday_session) do
          create(:console1984_session,
                 user:,
                 created_at: yesterday_date.beginning_of_day + 1.hour)
        end
        let!(:today_session) do
          create(:console1984_session,
                 user:,
                 created_at: Time.zone.today.beginning_of_day + 1.hour)
        end
        let!(:two_days_ago_session) do
          create(:console1984_session,
                 user:,
                 created_at: (yesterday_date - 1.day).beginning_of_day + 1.hour)
        end

        it 'only includes sessions from yesterday' do
          job.perform

          file_content = JSON.parse(File.read(expected_file_path))
          expect(file_content.length).to eq(1)
          expect(file_content.first['session_id']).to eq(yesterday_session.id)
        end
      end

      context 'when S3 upload fails' do
        let!(:user) { create(:console1984_user) }
        let!(:session) { create(:console1984_session, user:, created_at: yesterday_date.noon) }

        let(:s3_error) do
          Aws::S3::Errors::ServiceError.new(
            Seahorse::Client::RequestContext.new,
            'Access Denied'
          )
        end

        it 'logs the error and re-raises' do
          allow(Common::S3Helpers).to receive(:upload_file).and_raise(s3_error)

          expect(Rails.logger).to receive(:error).with(
            "Console access logs upload failed for #{expected_filename}: Access Denied"
          )

          expect { job.perform }.to raise_error(Aws::S3::Errors::ServiceError)
        end

        it 'leaves the file on disk for retry' do
          allow(Common::S3Helpers).to receive(:upload_file).and_raise(s3_error)

          expect { job.perform }.to raise_error(Aws::S3::Errors::ServiceError)

          expect(File.exist?(expected_file_path)).to be true
        end
      end
    end

    context 'when not in a valid environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'returns true without processing' do
        expect(job.perform).to be true
      end

      it 'does not create a log file' do
        job.perform

        expect(File.exist?(expected_file_path)).to be false
      end

      it 'does not upload to S3' do
        expect(Common::S3Helpers).not_to receive(:upload_file)

        job.perform
      end

      it 'does not log success message' do
        expect(Rails.logger).not_to receive(:info)

        job.perform
      end
    end
  end
end
