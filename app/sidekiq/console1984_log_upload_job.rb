# app/jobs/console1984_log_upload_job.rb

class Console1984LogUploadJob
  include Sidekiq::Job

  CONSOLE_LOGS_S3_BUCKET = 'vets-api-console-access-logs'
  AWS_REGION = 'us-gov-west-1'

  sidekiq_options queue: :default, retry: 1

  def perform
    return true if Settings.vsp_environment == 'development' || Settings.vsp_environment == 'staging'

    date = Date.yesterday
    start_time = date.beginning_of_day
    end_time = date.end_of_day

    filename = "console1984_logs_#{date}.json"
    file_path = Rails.root.join('tmp', 'console_access_logs', filename)

    begin
      log_file(file_path, start_time, end_time)
      upload_to_s3(file_path, filename)

      Rails.logger.info "Successfully uploaded #{filename} to S3"
    end
  end

  private

  def log_file(file_path, start_time, end_time)
    sessions = Console1984::Session
      .where(created_at: start_time..end_time)
      .includes(:user, commands: :sensitive_access)
      .map { |session| session_to_json(session) }

    File.open(file_path, 'w') do |file|
      file.write(JSON.pretty_generate(sessions))
    end
  end

  def session_to_json(session)
    {
      session_id: session.id,
      user: {
        id: session.user_id,
        username: session.user.username
      },
      reason: session.reason,
      started_at: session.created_at,
      ended_at: session.updated_at,
      commands: session.commands.map { |command| command_to_json(command) }
    }
  end

  def command_to_json(command)
    {
      id: command.id,
      timestamp: command.created_at,
      statements: command.statements,
      sensitive: command.sensitive_access_id.present?,
      sensitive_access: command.sensitive_access ? {
        id: command.sensitive_access_id,
        justification: command.sensitive_access.justification
      } : nil
    }
  end

def upload_to_s3(file_path, filename)
    s3_key = "console1984/#{filename}"
    manager = Aws::S3::TransferManager.new(
      client: Aws::S3::Client.new(region: AWS_REGION)
    )
    manager.upload(
      file_path,
      bucket: CONSOLE_LOGS_S3_BUCKET,
      key: s3_key,
      content_type: 'application/json',
      server_side_encryption: 'AES256'
    )
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error "Console access logs upload failed for #{filename}: #{e.message}"
    raise
  end
end
