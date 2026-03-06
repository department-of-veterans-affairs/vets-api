# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../script/coverage_collate'

RSpec.describe CoverageCollate do
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  describe '.rewrite_paths' do
    it 'rewrites /app/ paths to the workspace root' do
      resultset = <<~JSON
        {
          "/app/app/models/user.rb": [1, null, 0],
          "/app/lib/some_lib.rb": [1, 1, 1]
        }
      JSON
      file_path = File.join(temp_dir, '.resultset.json')
      File.write(file_path, resultset)

      described_class.rewrite_paths([file_path], '/workspace')

      content = File.read(file_path)
      expect(content).to include('"/workspace/app/models/user.rb"')
      expect(content).to include('"/workspace/lib/some_lib.rb"')
      expect(content).not_to include('"/app/')
    end

    it 'does not rewrite paths that are not at JSON key boundaries' do
      resultset = <<~JSON
        {
          "/app/modules/my_health/app/controllers/foo.rb": [1, 1]
        }
      JSON
      file_path = File.join(temp_dir, '.resultset.json')
      File.write(file_path, resultset)

      described_class.rewrite_paths([file_path], '/workspace')

      content = File.read(file_path)
      # The leading "/app/" is rewritten, but the interior /app/ in the path is preserved
      expect(content).to include('"/workspace/modules/my_health/app/controllers/foo.rb"')
    end

    it 'does not modify files without /app/ paths' do
      resultset = <<~JSON
        {
          "/home/runner/work/vets-api/app/models/user.rb": [1, 1]
        }
      JSON
      file_path = File.join(temp_dir, '.resultset.json')
      File.write(file_path, resultset)
      original_content = File.read(file_path)

      described_class.rewrite_paths([file_path], '/workspace')

      expect(File.read(file_path)).to eq(original_content)
    end

    it 'handles multiple files' do
      file1 = File.join(temp_dir, 'shard1.json')
      file2 = File.join(temp_dir, 'shard2.json')
      File.write(file1, '{ "/app/lib/a.rb": [1] }')
      File.write(file2, '{ "/app/lib/b.rb": [1] }')

      described_class.rewrite_paths([file1, file2], '/ws')

      expect(File.read(file1)).to include('"/ws/lib/a.rb"')
      expect(File.read(file2)).to include('"/ws/lib/b.rb"')
    end
  end

  describe '.run' do
    it 'aborts when no resultset files match the glob' do
      expect { described_class.run(glob: 'nonexistent-*/.resultset.json') }
        .to raise_error(SystemExit)
    end

    it 'rewrites paths and invokes SimpleCov.collate with matched files' do
      shard_dir = File.join(temp_dir, 'simplecov-resultset-1')
      FileUtils.mkdir_p(shard_dir)
      resultset_path = File.join(shard_dir, '.resultset.json')
      File.write(resultset_path, '{ "/app/lib/foo.rb": [1, 1] }')

      glob = File.join(temp_dir, 'simplecov-resultset-*/.resultset.json')

      allow(SimpleCov).to receive(:collate)

      described_class.run(glob:, workspace_root: '/workspace')

      # Verify paths were rewritten before collation
      expect(File.read(resultset_path)).to include('"/workspace/lib/foo.rb"')
      expect(SimpleCov).to have_received(:collate).with([resultset_path])
    end
  end
end
