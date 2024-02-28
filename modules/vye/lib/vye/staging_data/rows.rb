# frozen_string_literal: true

module Vye
  module StagingData
    Vye::StagingData::Rows = Struct.new(:idme_files, :icn_files) do
      def index
        @index ||= Hash.new { |h, k| h[k] = [] }
      end

      def get
        build
        note_missing_icn
        index.values.map { |rows| rows.blank? ? [] : [rows.first] }.flatten
      end

      private

      def idme_csv_each(&block)
        idme_files.each do |f|
          CSV.foreach(f, headers: true, &block)
        end
      end

      def icn_csv_each(&block)
        icn_files.each do |f|
          CSV.foreach(f, headers: true, &block)
        end
      end

      def build
        idme_csv_each do |csv|
          RowBuilder::BuildFromIdme.new(index:, csv:).call
        end

        icn_csv_each do |csv|
          RowBuilder::UpdateWithIcn.new(index:, csv:).call
        end
      end

      def note_missing_icn
        index.each_value do |rows|
          next if rows.any? { |row| row[:icn].present? }

          rows.each do |row|
            row[:notes] ||= []
            row[:notes].push(:missing_icn)
          end
        end
      end
    end
  end
end
