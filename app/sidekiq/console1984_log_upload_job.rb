# frozen_string_literal: true

require 'logging/helper/data_scrubber'
require 'fileutils'
require 'common/s3_helpers'

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
  ensure
    delete_log_file
  end

  private

  def valid_environment?
    Rails.env.production?
  end

  def create_log_file
    FileUtils.mkdir_p(folder_path)
    File.write(file_path, JSON.pretty_generate(sessions_data))
  end

  def upload_to_s3
    Common::S3Helpers.upload_file(
      s3_resource:,
      bucket: CONSOLE_LOGS_S3_BUCKET,
      key: "#{Settings.vsp_environment}/#{filename}",
      file_path:,
      content_type: 'application/json',
      server_side_encryption: 'AES256'
    )
  rescue Aws::S3::Errors::ServiceError => e
    Rails.logger.error "Console access logs upload failed for #{filename}: #{e.message}"
    raise
  end

  def s3_resource
    @s3_resource ||= Aws::S3::Resource.new(
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

  def folder_path
    'tmp/console_access_logs'
  end

  def file_path
    Rails.root.join(folder_path + "/#{filename}").to_s
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
      sensitive_access: sensitive_access_for_command(command)
    }
  end

  def sensitive_access_for_command(command)
    return nil unless command.sensitive_access

    {
      id: command.sensitive_access_id,
      justification: command.sensitive_access.justification
    }
  end

  def delete_log_file
    FileUtils.rm_f(file_path)
  end
end
