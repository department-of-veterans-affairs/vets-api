# frozen_string_literal: true

desc 'Lock and unlock user credentials'
namespace :user_credential do
  task :lock, %i[credential_id type] => :environment do |_, args|
    log_task_start(namespace: 'UserCredential::Lock', type: args[:type], credential_id: args[:credential_id])
    set_access_token(credential_id: args[:credential_id], type: args[:type])
    response = controller_instance.credential_lock
    log_task_success(namespace: 'UserCredential::Lock',
                     type: response[:type],
                     credential_id: response[:credential_id],
                     locked: response[:locked])
  end

  task :unlock, %i[credential_id type] => :environment do |_, args|
    log_task_start(namespace: 'UserCredential::Unlock', type: args[:type], credential_id: args[:credential_id])
    set_access_token(credential_id: args[:credential_id], type: args[:type])
    response = controller_instance.credential_unlock
    log_task_success(namespace: 'UserCredential::Unlock',
                     type: response[:type],
                     credential_id: response[:credential_id],
                     locked: response[:locked])
  end

  def set_access_token(credential_id:, type:)
    user_attributes = { 'credential_id' => credential_id, 'type' => type }
    user_identifier = 'rake_task'
    token = Struct.new(:user_attributes, :user_identifier)
    service_account_access_token = token.new(user_attributes, user_identifier)
    controller_instance.instance_variable_set(:@service_account_access_token, service_account_access_token)
  end

  def log_task_start(namespace:, type:, credential_id:)
    puts "[#{namespace}] rake task start - type: #{type}, credential_id: #{credential_id}"
  end

  def log_task_success(namespace:, type:, credential_id:, locked:)
    puts "[#{namespace}] rake task complete - type: #{type}, credential_id: #{credential_id}, locked: #{locked}"
  end

  def controller_instance
    @controller_instance ||= V0::AccountControlsController.new
  end
end
