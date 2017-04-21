# frozen_string_literal: true
require 'rails_helper'
require 'shrine'
require 'shrine/storage/memory'
require 'shrine/plugins/validate_virus_free'




describe Shrine::Plugins::ValidateVirusFree do
  let(:uploader) do
    uploader_class = Class.new(Shrine)
    uploader_class.storages[:cache] = Shrine::Storage::Memory.new
    uploader_class.storages[:store] = Shrine::Storage::Memory.new
    uploader_class.new(:store)
  end

  let(:attacher) do
    Object.send(:remove_const, "User") if defined?(User) # for warnings
    user_class = Object.const_set("User", Struct.new(:avatar_data, :id))
    user_class.include uploader.class::Attachment.new(:avatar)
    user_class.new.avatar_attacher
  end

  describe '#validate_virus_free' do
    it 'adds an error if clam scan returns not safe' do
      a = attacher do
        plugin :validation_helpers
        plugin :validate_virus_free
      end
      puts a.methods
    end
  end
end
