# frozen_string_literal: true

namespace :hca_attachments do
  desc 'Rotate the encryption keys'
  task migrate_inflection: :environment do
    FormAttachment.where(type: 'HcaAttachment').find_each { |hca| hca.update(type: 'HCAAttachment') }
  end
end
