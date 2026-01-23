# frozen_string_literal: true

require 'ivc_champva/monitor'

module IvcChampva
  class DocumentMerger
    attr_reader :form_id, :legacy_form_id, :file_paths, :attachment_ids, :current_user

    # Configuration-driven merging rules
    MERGE_RULES = {
      'vha_10_7959c' => {
        'medicare_cards' => {
          flipper_toggle: 'champva_docmerge_10_7959c_medicare',
          attachment_ids: ['Front of Medicare card', 'Back of Medicare card'],
          merged_attachment_id: 'Medicare card',
          max_docs_merged: 2 # only combine one set of front/back
        },
        'medicare_part_d_cards' => {
          flipper_toggle: 'champva_docmerge_10_7959c_medicare_pt_d',
          attachment_ids: ['Front of Medicare Part D card', 'Back of Medicare Part D card'],
          merged_attachment_id: 'Medicare Part D card',
          max_docs_merged: 2
        },
        'ohi_cards' => {
          flipper_toggle: 'champva_docmerge_10_7959c_ohi',
          attachment_ids: ['Front of insurance card', 'Back of insurance card'],
          merged_attachment_id: 'Insurance card',
          max_docs_merged: 2
        }
      }
    }.freeze

    # Default size limit for merged PDFs (in bytes)
    DEFAULT_SIZE_LIMIT = 200.megabytes

    ##
    # Initialize new document merger
    #
    # @param [String] form_id The ID of the current form, e.g., 'vha_10_7959c'
    # @param [Array] file_paths List of local file paths of all attachments to be merged
    # @param [Array] attachment_ids List of attachment_ids corresponding to file_paths
    # @param [User] current_user The current user, used for feature flags
    # @param [Hash] options Additional options (size_limit, etc.)
    #
    # @return [IvcChampva::DocumentMerger]
    #
    def initialize(form_id, file_paths, attachment_ids, current_user = nil, options = {})
      raise ArgumentError, 'form_id is required' if form_id.blank?

      @form_id = form_id
      @legacy_form_id = IvcChampva::FormVersionManager.get_legacy_form_id(@form_id)
      @file_paths = Array(file_paths)
      @attachment_ids = Array(attachment_ids)
      @current_user = current_user
      @size_limit = options[:size_limit] || DEFAULT_SIZE_LIMIT
      @uuid = options[:uuid] || SecureRandom.uuid
    end

    ##
    # Main processing method that orchestrates document merging
    #
    # @return [Hash] Result containing merged file paths and updated attachment_ids
    #   {
    #     merged_file_paths: Array of paths to merged PDF files,
    #     updated_attachment_ids: Array of attachment_ids for merged files
    #   }
    def process
      Rails.logger.info "IVC ChampVA DocumentMerger - Starting merge process for form #{@form_id} " \
                        "with #{@file_paths.length} files"

      # Return original files if no merge rules apply
      return build_no_merge_result unless should_merge?

      grouped_files = group_files_by_merge_rules
      merged_results = process_grouped_files(grouped_files)
      build_merge_result(merged_results)
    rescue => e
      Rails.logger.error("IVC ChampVA DocumentMerger - Error during merge process: #{e.message}")
      monitor.track_merge_error(@uuid, e.message)
      # Return original files on error as fallback
      build_no_merge_result
    end

    private

    ##
    # Determines if any merging should be performed based on form rules and feature flags
    #
    # @return [Boolean] true if merging should be performed
    def should_merge?
      return false unless Flipper.enabled?(:champva_document_merging, @current_user)
      return false unless MERGE_RULES.key?(@legacy_form_id)

      MERGE_RULES[@legacy_form_id].any? do |_rule_name, rule_config|
        return true if Flipper.enabled?(rule_config[:flipper_toggle], @current_user)
      end

      false
    end

    ##
    # Groups files by applicable merge rules
    #
    # @return [Hash] Hash with rule names as keys and file info arrays as values
    #   {
    #     'medicare_cards' => [
    #       { file_path: '/path/to/file', attachment_id: 'Front of Medicare card', index: 0 },
    #       { file_path: '/path/to/file2', attachment_id: 'Back of Medicare card', index: 1 }
    #     ],
    #     'ungrouped' => [
    #       { file_path: '/path/to/file3', attachment_id: 'Other document', index: 2 }
    #     ]
    #   }
    def group_files_by_merge_rules # rubocop:disable Metrics/MethodLength
      grouped = { 'ungrouped' => [] }
      form_rules = MERGE_RULES[@legacy_form_id] || {}

      @file_paths.each_with_index do |file_path, index|
        attachment_id = @attachment_ids[index]
        rule_name = find_applicable_rule(attachment_id, form_rules)

        if rule_name && Flipper.enabled?(form_rules[rule_name][:flipper_toggle], @current_user)
          grouped[rule_name] ||= []
          grouped[rule_name] << {
            file_path:,
            attachment_id:,
            index:
          }
        else
          grouped['ungrouped'] << {
            file_path:,
            attachment_id:,
            index:
          }
        end
      end

      grouped
    end

    ##
    # Finds the applicable merge rule for a given attachment_id
    #
    # @param [String] attachment_id The attachment ID to match
    # @param [Hash] form_rules The merge rules for the current form
    # @return [String, nil] The rule name if found, nil otherwise
    def find_applicable_rule(attachment_id, form_rules)
      form_rules.each do |rule_name, rule_config|
        return rule_name if rule_config[:attachment_ids].include?(attachment_id)
      end
      nil
    end

    ##
    # Processes each group of files according to their merge rules
    #
    # @param [Hash] grouped_files Files grouped by merge rules
    # @return [Array] Array of merge results
    def process_grouped_files(grouped_files)
      results = []

      grouped_files.each do |rule_name, files|
        next if files.empty?

        if rule_name == 'ungrouped'
          # Add ungrouped files to results without merging
          files.each { |file_info| results << build_individual_file_result(file_info, 'ungrouped') }
        else
          merge_result = process_merge_rule(rule_name, files)
          results.concat(merge_result) if merge_result
        end
      end

      results
    end

    ##
    # Processes a specific merge rule with its associated files
    #
    # @param [String] rule_name The name of the merge rule
    # @param [Array] files Array of file info hashes
    # @return [Array] Array of merge results for this rule
    def process_merge_rule(rule_name, files)
      rule_config = MERGE_RULES[@legacy_form_id][rule_name]

      Rails.logger.info "IVC ChampVA DocumentMerger - Processing rule '#{rule_name}' with #{files.length} files"

      file_batches = create_rule_based_batches(files, rule_config[:max_docs_merged])

      results = []
      file_batches.each_with_index do |batch, batch_index|
        size_chunks = create_size_based_chunks(batch)

        size_chunks.each_with_index do |chunk, chunk_index|
          result = merge_file_chunk(rule_name, rule_config, chunk, batch_index, chunk_index)
          if result
            # Success case: merge_file_chunk returned merged result
            results << result
          else
            # Error case: merge failed, add individual files as fallback
            chunk.each { |file_info| results << build_individual_file_result(file_info) }
          end
        end
      end

      results
    end

    ##
    # Creates batches of files based on rule constraints (e.g., pairs of front/back)
    #
    # @param [Array] files Array of file info hashes
    # @param [Integer, nil] max_docs_merged Maximum documents per batch
    # @return [Array] Array of file batches
    def create_rule_based_batches(files, max_docs_merged)
      return [files] unless max_docs_merged

      files.each_slice(max_docs_merged).to_a
    end

    ##
    # Creates chunks of files based on size limits
    #
    # @param [Array] files Array of file info hashes
    # @return [Array] Array of file chunks
    def create_size_based_chunks(files)
      chunks = []
      current_chunk = []
      current_size = 0

      files.each do |file_info|
        file_size = File.size(file_info[:file_path])

        if current_size + file_size > @size_limit && !current_chunk.empty?
          # Start new chunk
          chunks << current_chunk
          current_chunk = [file_info]
          current_size = file_size
        else
          current_chunk << file_info
          current_size += file_size
        end
      end

      chunks << current_chunk unless current_chunk.empty?
      chunks
    end

    ##
    # Merges a chunk of files into a single PDF
    #
    # @param [String] rule_name The name of the merge rule
    # @param [Hash] rule_config The merge rule configuration
    # @param [Array] file_chunk Array of file info hashes to merge
    # @param [Integer] batch_index Index of the batch (for naming)
    # @param [Integer] chunk_index Index of the chunk within batch (for naming)
    # @return [Hash, nil] Merge result hash or nil on failure
    def merge_file_chunk(rule_name, rule_config, file_chunk, batch_index, chunk_index)
      return nil if file_chunk.empty?

      merged_file_path = generate_merged_file_path(rule_config[:merged_attachment_id], batch_index, chunk_index)
      file_paths_to_merge = file_chunk.map { |f| f[:file_path] }

      Rails.logger.info "IVC ChampVA DocumentMerger - Merging #{file_paths_to_merge.length} files " \
                        "into #{File.basename(merged_file_path)}"

      begin
        IvcChampva::PdfCombiner.combine(merged_file_path, file_paths_to_merge)

        {
          merged_file_path:,
          merged_attachment_id: rule_config[:merged_attachment_id],
          original_files: file_chunk,
          rule_name:
        }
      rescue => e
        Rails.logger.error("IVC ChampVA DocumentMerger - Failed to merge files for rule '#{rule_name}': #{e.message}")
        monitor.track_merge_error(@uuid, "Rule: #{rule_name}, Error: #{e.message}")
        nil
      end
    end

    ##
    # Generates a file path for the merged PDF
    #
    # @param [String] base_attachment_id Base attachment ID for naming
    # @param [Integer] batch_index Index of the batch
    # @param [Integer] chunk_index Index of the chunk within batch
    # @return [String] Full file path for the merged PDF
    def generate_merged_file_path(base_attachment_id, batch_index, chunk_index)
      safe_attachment_id = base_attachment_id.downcase.gsub(/[^a-z0-9]/, '_')

      # Always include batch and chunk indexes for consistent naming
      suffix = "_#{batch_index}_#{chunk_index}"

      File.join('tmp/', "#{@uuid}_#{@form_id}_#{safe_attachment_id}#{suffix}_merged.pdf")
    end

    ##
    # Builds the final result hash from merge results
    #
    # @param [Array] merged_results Array of merge result hashes
    # @return [Hash] Final result hash
    def build_merge_result(merged_results)
      {
        merged_file_paths: merged_results.map { |r| r[:merged_file_path] },
        updated_attachment_ids: merged_results.map { |r| r[:merged_attachment_id] }
      }
    end

    ##
    # Builds the result hash when no merging is performed
    #
    # @return [Hash] Result hash with original files
    def build_no_merge_result
      {
        merged_file_paths: @file_paths,
        updated_attachment_ids: @attachment_ids
      }
    end

    ##
    # Build result for an individual file (used for error fallback and ungrouped files)
    #
    # @param [Hash] file_info File information hash
    # @param [String, nil] rule_name Rule name to assign (default: nil)
    # @return [Hash] Individual file result
    def build_individual_file_result(file_info, rule_name = nil)
      {
        merged_file_path: file_info[:file_path],
        merged_attachment_id: file_info[:attachment_id],
        original_files: [file_info],
        rule_name:
      }
    end

    ##
    # Retrieve a monitor for tracking
    #
    # @return [IvcChampva::Monitor]
    def monitor
      @monitor ||= IvcChampva::Monitor.new
    end
  end
end
