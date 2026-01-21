# frozen_string_literal: true

class Console1984LogUploadJob
  include Sidekiq::Job

  CONSOLE_LOGS_S3_BUCKET = 'vets-api-console-access-logs'
  AWS_REGION = 'us-gov-west-1'

  sidekiq_options queue: :default, retry: 1

  def perform
    return true unless valid_environment?

    create_log_file
    upload_to_s3

    Rails.logger.info "Successfully uploaded #{filename} to S3"
  end

  private

  def valid_environment?
    Rails.env.development? || Settings.vsp_environment == 'development' || Settings.vsp_environment == 'staging'
  end

  def create_log_file
    File.write(file_path, JSON.pretty_generate(sessions_data))
  end

  def upload_to_s3
    transfer_manager.upload_file(
      file_path,
      bucket: CONSOLE_LOGS_S3_BUCKET,
      key: "console1984/#{filename}",
      content_type: 'application/json',
      server_side_encryption: 'AES256'
    )
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error "Console access logs upload failed for #{filename}: #{e.message}"
    raise
  end

  def transfer_manager
    @manager ||= Aws::S3::TransferManager.new(
      client: Aws::S3::Client.new(region: AWS_REGION)
    )
  end

  def yesterday
    @yesterday ||= Date.yesterday
  end

  def yesterday_range
    yesterday.all_day
  end

  def filename
    "console1984_logs_#{yesterday}.json"
  end

  def file_path
    Rails.root.join('tmp', 'console_access_logs', filename).to_s
  end

  def sessions_data
    Console1984::Session
      .where(created_at: yesterday_range)
      .includes(:user, commands: :sensitive_access)
      .map { |session| session_to_json(session) }
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
      sensitive_access: if command.sensitive_access
                          {
                            id: command.sensitive_access_id,
                            justification: command.sensitive_access.justification
                          }
                        end
    }
  end
end
