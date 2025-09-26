# frozen_string_literal: true

module PdfTestHelpers
  def process_specific_temp_dir
    @process_temp_dir ||= Rails.root.join("tmp/test_pdfs/process_#{test_env_number}")
  end

  def test_env_number
    Process.pid.to_s
  end

  def ensure_temp_dir_exists
    FileUtils.mkdir_p(process_specific_temp_dir)
  end

  def pdf_temp_path(filename)
    ensure_temp_dir_exists
    process_specific_temp_dir.join(filename)
  end

  def cleanup_process_temp_dir
    FileUtils.rm_rf(process_specific_temp_dir)
  end
end
