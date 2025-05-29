# frozen_string_literal: true

module DebtsApi
  module V0
    class Form5655SubmissionSerializer
      def initialize(submission)
        @submission = submission
      end

      def serialize
        {
          'id' => @submission.id,
          'created_at' => @submission.created_at,
          'updated_at' => @submission.updated_at,
          'state' => @submission.state,
          'metadata' => serialize_metadata
        }
      end

      private

      def serialize_metadata
        return {} if @submission.public_metadata.blank?

        {
          'debt_type' => @submission.public_metadata['debt_type'],
          'streamlined' => @submission.public_metadata['streamlined'],
          'combined' => @submission.public_metadata['combined'],
          'debt_identifiers' => extract_debt_identifiers
        }
      end

      def extract_debt_identifiers
        return [] if @submission.metadata.blank?

        metadata = JSON.parse(@submission.metadata)
        debts = metadata['debts'] || metadata['copays'] || []

        if @submission.public_metadata['debt_type'] == 'DEBT'
          extract_vba_debt_identifiers(debts)
        elsif @submission.public_metadata['debt_type'] == 'COPAY'
          extract_vha_copay_identifiers(debts)
        else
          []
        end
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to extract debt identifiers for submission #{@submission.id}: #{e.message}")
        []
      end

      def extract_vba_debt_identifiers(debts)
        debts.map do |debt|
          # Build composite debt ID
          "#{debt['deductionCode']}#{debt['originalAR'].to_i}"
        end.compact
      end

      def extract_vha_copay_identifiers(copays)
        copays.pluck('id').compact
      end
    end
  end
end
