# frozen_string_literal: true

# Temporary performance test for PDF merging
# This file will be deleted after testing

require 'securerandom'
require 'benchmark'
require 'fileutils'

class TempPdfMergePerformanceTest
  def self.run_test
    puts 'Starting PDF merge performance test with 100 files...'

    # Setup paths
    source_pdf = Pathname.new('/Users/broskj/openai/SampleBC.pdf')
    temp_dir = Rails.root.join('tmp', 'pdf_performance_test')
    FileUtils.mkdir_p(temp_dir)

    # Generate 100 copies of the sample PDF with unique names
    file_paths = []
    puts 'Creating 100 copies of SampleBC.pdf...'

    copy_time = Benchmark.realtime do
      100.times do
        uuid = SecureRandom.uuid
        temp_file_path = temp_dir.join("sample_eob_#{uuid}.pdf")
        FileUtils.copy_file(source_pdf, temp_file_path)
        file_paths << temp_file_path.to_s
      end
    end

    puts "File copying completed in #{copy_time.round(3)} seconds"
    puts "Total file size: #{(File.size(source_pdf) * 100 / 1024.0 / 1024.0).round(2)} MB"

    # Test PDF merging performance
    merged_pdf_path = temp_dir.join("merged_performance_test_#{SecureRandom.uuid}.pdf")

    puts 'Starting PDF merge operation...'
    merge_time = Benchmark.realtime do
      IvcChampva::PdfCombiner.combine(merged_pdf_path.to_s, file_paths)
    end

    puts "PDF merge completed in #{merge_time.round(3)} seconds"

    # Verify the merged file
    if File.exist?(merged_pdf_path)
      merged_size = File.size(merged_pdf_path)
      puts "Merged PDF size: #{(merged_size / 1024.0 / 1024.0).round(2)} MB"

      # Check page count using CombinePDF
      begin
        merged_pdf = CombinePDF.load(merged_pdf_path.to_s)
        puts "Merged PDF contains #{merged_pdf.pages.count} pages"
      rescue => e
        puts "Error reading merged PDF: #{e.message}"
      end
    else
      puts 'ERROR: Merged PDF was not created!'
    end

    # Performance summary
    puts "\n=== PERFORMANCE SUMMARY ==="
    puts "File copying time: #{copy_time.round(3)} seconds"
    puts "PDF merging time: #{merge_time.round(3)} seconds"
    puts "Total operation time: #{(copy_time + merge_time).round(3)} seconds"
    puts "Average time per file merge: #{(merge_time / 100).round(4)} seconds"

    # Memory usage estimation
    puts "\nMemory considerations:"
    puts "- Each source PDF: #{(File.size(source_pdf) / 1024.0).round(2)} KB"
    puts "- 100 files total: #{(File.size(source_pdf) * 100 / 1024.0 / 1024.0).round(2)} MB"
  rescue => e
    puts "ERROR during test: #{e.message}"
    puts e.backtrace.first(5)
  ensure
    # Cleanup: Remove all temporary files
    puts "\nCleaning up temporary files..."
    cleanup_time = Benchmark.realtime do
      FileUtils.rm_rf(temp_dir)
    end
    puts "Cleanup completed in #{cleanup_time.round(3)} seconds"
    puts 'Test completed successfully!'
  end
end

# Run the test if this file is executed directly
TempPdfMergePerformanceTest.run_test if __FILE__ == $PROGRAM_NAME
