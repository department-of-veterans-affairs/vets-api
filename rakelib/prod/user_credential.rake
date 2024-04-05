# frozen_string_literal: true

desc 'Lock and unlock user credentials'
namespace :user_credential do
  task :lock, %i[type credential_id requested_by] => :environment do |_, args|
    namespace = 'UserCredential::Lock'
    validate_args(args)
    type = args[:type]
    credential_id = args[:credential_id]
    context = { type:, credential_id:, requested_by: args[:requested_by] }
    log_task(namespace:, status: 'start', context:)
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.lock!
    log_task(namespace:, status: 'complete', context: context.merge(locked: user_verification.locked))
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
    log_task(namespace:, status: 'start', context:)
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.unlock!
    log_task(namespace:, status: 'complete', context: context.merge(locked: user_verification.locked))
    puts "#{namespace} complete - #{type}_uuid: #{credential_id}"
  rescue => e
    puts "#{namespace} failed - #{e.message}"
  end

  def validate_args(args)
    raise 'Missing required arguments' if args[:type].blank? ||
                                          args[:credential_id].blank? ||
                                          args[:requested_by].blank?
  end

  def log_task(namespace:, status:, context:)
    Rails.logger.info("[#{namespace}] rake task #{status}", context)
  end
end
