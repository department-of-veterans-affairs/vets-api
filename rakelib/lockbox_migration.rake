# frozen_string_literal: true

namespace :lockbox do
  desc 'migrate from attr_encrypted to lockbox'
  task migrate_db: :environment do
    HealthQuest::QuestionnaireResponse.skip_callback(:save, :before, :set_user_demographics, raise: false)

    models = ApplicationRecord.descendants.select do |model|
      model.descendants.empty? && !model.encrypted_attributes.empty?
    end
    models.map(&:name).each do |m|
      puts "migrating model..... #{m.constantize}"
      Lockbox.migrate(m.constantize)
    end

    HealthQuest::QuestionnaireResponse.set_callback(:save, :before, :set_user_demographics, raise: false)
  end
end
