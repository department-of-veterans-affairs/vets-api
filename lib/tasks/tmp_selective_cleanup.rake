# lib/tasks/tmp_selective_cleanup.rake
namespace :tmp do
  desc 'Clear tmp but keep pids, cache, and sockets'
  task selective_clear: [:environment] do
    root = Rails.root.join('tmp').to_s
    keep = %w[pids cache sockets].map { |d| File.join(root, d) }

    Dir.glob(File.join(root, '*'), File::FNM_DOTMATCH).each do |path|
      # Skip current dir, parent dir, and anything in the keep list
      next if %w[. ..].include?(File.basename(path))
      next if keep.any? { |k| path.start_with?(k) }

      FileUtils.rm_rf(path)
    end
  end
end

# Only enhance parallel:spec if we're not in CI
unless ENV['CI']
  Rake::Task['parallel:spec'].enhance do
    Rake::Task['tmp:selective_clear'].invoke
  end
end
