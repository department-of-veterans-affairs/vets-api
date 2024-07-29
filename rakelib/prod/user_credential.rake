# frozen_string_literal: true

desc 'Lock and unlock user credentials'
namespace :user_credential do
  task :lock, %i[type credential_id requested_by] => :environment do |_, args|
    run_task(:lock, args)
  end

  task :unlock, %i[type credential_id requested_by] => :environment do |_, args|
    run_task(:unlock, args)
  end

  task :lock_all, %i[icn requested_by] => :environment do |_, args|
    run_task(:lock_all, args, all_credentials: true)
  end

  task :unlock_all, %i[icn requested_by] => :environment do |_, args|
    run_task(:unlock_all, args, all_credentials: true)
  end

  def run_task(action, args, all_credentials: false)
    namespace = "UserCredential::#{action.to_s.camelize}"
    lock_action = %i[lock lock_all].include?(action) ? :lock : :unlock
    validate_args(args, all_credentials)
    context = build_context(args)
    log_message(level: 'info', message: "[#{namespace}] rake task start, context: #{context.to_json}")

    if all_credentials
      UserAccount.find_by(icn: args[:icn]).user_verifications.each do |user_verification|
        update_credential(user_verification, lock_action, namespace, context)
      end
    else
      user_verification = UserVerification.where(["#{args[:type]}_uuid = ?", args[:credential_id]]).first
      update_credential(user_verification, lock_action, namespace, context)
    end
    log_message(level: 'info', message: "[#{namespace}] rake task complete, context: #{context.to_json}")
  rescue => e
    log_message(level: 'error', message: "[#{namespace}] failed - #{e.message}")
  end

  def validate_args(args, all_credentials)
    missing_args = all_credentials ? %i[icn requested_by] : %i[type credential_id requested_by]
    raise 'Missing required arguments' unless args.values_at(*missing_args).all?
    raise 'Invalid type' if SignIn::Constants::Auth::CSP_TYPES.exclude?(args[:type]) && !all_credentials
  end

  def build_context(args)
    { icn: args[:icn],
      type: args[:type],
      credential_id: args[:credential_id],
      requested_by: args[:requested_by] }.compact
  end

  def update_credential(user_verification, lock_action, namespace, context)
    user_verification.send("#{lock_action}!")
    credential_context = context.merge({ type: user_verification.credential_type,
                                         credential_id: user_verification.credential_identifier,
                                         locked: user_verification.locked }).compact
    log_message(level: 'info',
                message: "[#{namespace}] credential #{lock_action}, context: #{credential_context.to_json}")
  end

  def log_message(level:, message:)
    `echo "#{datadog_log(level:, message:).to_json.dump}" >> /proc/1/fd/1` if Rails.env.production?
    puts message
  end

  def datadog_log(level:, message:)
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
