# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/storage_from_config'

describe Shrine::Plugins::StorageFromConfig do
  let(:uploader) do
    Class.new(Shrine).tap do |k|
      k.plugin :storage_from_config, settings:
    end
  end

  let(:instance) { uploader.new(:cache).storage }

  context 'with local storage settings' do
    let(:settings) { Settings.shrine.local }

    it 'returns a filesystem store' do
      expect(instance).to be_a(Shrine::Storage::FileSystem)
      expect(instance.prefix.to_s).to eq("uploads/#{settings.path}/cache")
    end
  end

  context 'with s3 storage settings' do
    let(:settings) { Settings.shrine.remotes3 }

    it 'returns an s3 store' do
      expect(instance).to be_a(Shrine::Storage::S3)
      expect(instance.prefix.to_s).to eq("#{settings.path}/cache")
    end
  end
end
