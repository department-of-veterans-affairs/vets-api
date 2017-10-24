# frozen_string_literal: true
require 'rails_helper'

describe DataMigrations::PersistentAttachment do
  it 'should migrate the records' do
    persistent_attachment = PersistentAttachment.new(file_data: 'foo')
    persistent_attachment.type = 'PersistentAttachment::PensionBurial'
    persistent_attachment.save(validate: false)

    DataMigrations::PersistentAttachment.run
    expect(persistent_attachment.reload.type).to eq('PersistentAttachments::PensionBurial')
  end
end
