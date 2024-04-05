# frozen_string_literal: true

desc 'Lock and unlock user credentials'
namespace :user_credential do
  task :lock, %i[credential_id type] => :environment do |_, args|
    type, credential_id = args[:type], args[:credential_id]
    log_task(namespace: 'UserCredential::Lock',   
             status: 'start',   
             context: { type:, credential_id: })
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.lock!
    log_task(namespace: 'UserCredential::Lock', 
             status: 'complete',  
             context: { type:, credential_id:, locked: user_verification.locked })
  end

  task :unlock, %i[credential_id type] => :environment do |_, args|
    type, credential_id = args[:type], args[:credential_id]
    log_task(namespace: 'UserCredential::Unlock',   
             status: 'start',   
             context: { type:, credential_id: })
    user_verification = UserVerification.where(["#{type}_uuid = ?", credential_id]).first
    user_verification.unlock!
    log_task(namespace: 'UserCredential::Unlock', 
             status: 'complete',  
             context: { type:, credential_id:, locked: user_verification.locked })
  end

  def log_task(namespace:, status:, context:)
    Rails.logger.info("[#{namespace}] rake task #{status}", context)
  end
end
