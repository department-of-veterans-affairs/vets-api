# frozen_string_literal: true

module RapidReadyForDecision
  class LighthouseMedicationRequestData
    attr_accessor :response

    def initialize(response)
      @response = response
    end

    def transform
      transformed_entries = filtered_entries.map { |entry| transform_entry(entry) }
      sorted_entries(transformed_entries)
    end

    private

    def sorted_entries(transformed_entries)
      transformed_entries.sort_by { |med| [med[:authoredOn].to_datetime, med[:description]] }.reverse!
    end

    def filtered_entries
      response.body['entry'].filter { |entry| entry['resource']['status'] == 'active' }
    end

    def transform_entry(raw_entry)
      entry = raw_entry['resource'].slice(
        'status', 'medicationReference', 'subject', 'authoredOn', 'note', 'dosageInstruction'
      )

      MedicationEntry.new(entry).result
    end

    MedicationEntry = Struct.new(:entry) do
      def result
        entry.slice('status', 'authoredOn', entry)
             .merge(description_hash, notes_hash, dosage_hash).with_indifferent_access
      end

      def description_hash
        { description: entry['medicationReference']['display'] }
      end

      def notes_hash
        verbose_notes = (entry['note'] || [])

        { 'notes': verbose_notes.map { |note| note['text'] } }
      end

      def dosage_hash
        dosage_instructions = (entry['dosageInstruction'] || [])
        toplevel_texts = dosage_instructions.map { |instr| instr['text'] || [] }
        code_texts = dosage_instructions.map { |instr| instr.dig('timing', 'code', 'text') || [] }

        { 'dosageInstructions': toplevel_texts + code_texts }
      end
    end
  end
end
