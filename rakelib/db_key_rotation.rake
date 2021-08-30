# frozen_string_literal: true

# require 'database/key_rotation'
require 'sentry_logging'

# This iterates over each record (with attrs encrypted via attr_encrypted)
# decrypts with the old key, re-saves and encrypts with the new key
# any new db fields using attr_encrypted will need to be
# added to this rake task

# FormAttachment.where(type: "HcaAttachment").update_all(type: "HCAAttachment")

namespace :attr_encrypted do
  desc 'Rotate the encryption keys'
  task rotate_keys: :environment do
    # overriding/monkey patching the encryption_key method
    # in order to rotate the Settings.db_encryption_key
    # module Database
    #   module KeyRotation
    #     def encryption_key(attribute)
    #       if decrypting?(attribute)
    #         @database_key || Settings.old_db_encryption_key
    #       else
    #         Settings.db_encryption_key
    #       end
    #     end
    #   end
    # end
    ActiveRecord::Base.transaction do
      ApplicationRecord.descendants.each do |model|
        unless model.encrypted_attributes.empty?
          puts "updating database encryption key for: #{model.name}"
          encrypted_attributes = model.encrypted_attributes.keys
          model.all.each do |record|
            encrypted_attributes.each do |attribute|
              old_attribute = record.send(attribute)
              record.send("#{attribute}=", old_attribute)
              record.save!
              # rescue
              #   record.database_key = Settings.db_encryption_key
            end
          end
        end
      rescue => e
        puts "....rolling back transaction. Error occured: #{e.inspect}"
        Rails.logger.error("Error running the db key rotation rake task, rolling back: #{e}")
        raise ActiveRecord::Rollback # makes sure the transaction gets completely rolled back
      end
    end
  end
end
