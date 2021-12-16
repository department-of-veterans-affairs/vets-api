# frozen_string_literal: true

module FastTrack
  class HypertensionMedicationRequestData
    attr_accessor :response

    def initialize(response)
      @response = response
    end

    def transform
      entries = response.body['entry']
      filtered = entries.filter { |entry| entry['resource']['status'] == 'active' }
      filtered.map { |entry| transform_entry(entry) }
    end

    private

    def transform_entry(raw_entry)
      entry = raw_entry['resource'].slice(
        'status', 'medicationReference', 'subject', 'authoredOn', 'note', 'dosageInstruction'
      )
      result = entry.slice('status', 'authoredOn', entry)
      description_hash = { description: entry['medicationReference']['display'] }
      notes_hash = get_notes_from_note(entry['note'] || [])
      dosage_hash = get_text_from_dosage_instruction(entry['dosageInstruction'] || [])
      result.merge(description_hash, notes_hash, dosage_hash).with_indifferent_access
    end

    def get_notes_from_note(verbose_notes)
      { 'notes': verbose_notes.map { |note| note['text'] } }
    end

    def get_text_from_dosage_instruction(dosage_instructions)
      toplevel_texts = dosage_instructions.map { |instr| instr['text'] || [] }
      code_texts = dosage_instructions.map { |instr| instr.dig('timing', 'code', 'text') || [] }
      { 'dosageInstructions': toplevel_texts + code_texts }
    end
  end
end
