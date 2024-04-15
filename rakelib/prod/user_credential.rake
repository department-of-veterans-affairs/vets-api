# frozen_string_literal: true

desc 'Lock and unlock user credentials'
namespace :user_credential do
  task :lock, %i[type credential_id requested_by] => :environment do |_, args|
    namespace = 'UserCredential::Lock'
    validate_args(args)
    type = args[:type]
    credential_id = args[:credential_id]
    context = { type:, credential_id:, requested_by: args[:requested_by] }
    log_to_stdout(level: 'info', message: "[#{namespace}] rake task start, context: #{context.to_json}")
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.lock!
    context[:locked] = user_verification.locked
    log_to_stdout(level: 'info', message: "[#{namespace}] rake task complete, context: #{context.to_json}")
    puts "#{namespace} complete - #{type}_uuid: #{credential_id}"
  rescue => e
    puts "#{namespace} failed - #{e.message}"
  end

  task :unlock, %i[type credential_id requested_by] => :environment do |_, args|
    namespace = 'UserCredential::Unlock'
    validate_args(args)
    type = args[:type]
    credential_id = args[:credential_id]
    context = { type:, credential_id:, requested_by: args[:requested_by] }
    log_to_stdout(level: 'info', message: "[#{namespace}] rake task start, context: #{context.to_json}")
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.unlock!
    context[:locked] = user_verification.locked
    log_to_stdout(level: 'info', message: "[#{namespace}] rake task complete, context: #{context.to_json}")
    puts "#{namespace} complete - #{type}_uuid: #{credential_id}"
  rescue => e
    puts "#{namespace} failed - #{e.message}"
  end

  def validate_args(args)
    raise 'Missing required arguments' if args[:type].blank? ||
                                          args[:credential_id].blank? ||
                                          args[:requested_by].blank?
  end

  def log_to_stdout(level:, message:)
    `echo "#{log_message(level:, message:).to_json.dump}" >> /proc/1/fd/1`
  end

  def log_message(level:, message:)
    {
      level:,
      message:,
      application: 'vets-api-server',
      environment: Rails.env,
      timestamp: Time.zone.now.iso8601,

      file: 'rakelib/prod/user_credential.rake',
      named_tags: {
        dd: {
          env: ENV.fetch('DD_ENV', nil),
          service: 'vets-api'
        },
        ddsource: 'ruby'
      },
      name: 'Rails'
    }
  end
end
