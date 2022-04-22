# frozen_string_literal: true

module RapidReadyForDecision
  class LighthouseMedicationRequestData
    def initialize(response)
      @response = response
    end

    def count
      # Should be the same as @response.body["total"]
      resources.size
    end

    def resources
      @resources ||= @response.blank? ? [] : @response.body['entry'].map { |mr| mr['resource'] }
    end

    def transform
      active_med_requests.map { |resource| MedicationEntry.new(resource).result }
                         .sort_by { |med| [med[:authoredOn].to_datetime, med[:description]] }
                         .reverse!
    end

    private

    def active_med_requests
      resources.filter { |resource| resource['status'] == 'active' }
    end

    MedicationEntry = Struct.new(:entry) do
      def result
        entry.slice('status', 'authoredOn')
             .merge(description_hash, notes_hash, dosage_hash, dispense_request_hash)
             .with_indifferent_access
      end

      def description_hash
        { description: entry['medicationReference']['display'] }
      end

      def notes_hash
        verbose_notes = (entry['note'] || [])

        { notes: verbose_notes.map { |note| note['text'] } }
      end

      def dosage_hash
        dosage_instructions = (entry['dosageInstruction'] || [])
        toplevel_texts = dosage_instructions.map { |instr| instr['text'] || [] }
        code_texts = dosage_instructions.map { |instr| instr.dig('timing', 'code', 'text') || [] }
        routes = dosage_instructions.map { |instr| instr.dig('route', 'text') }.join(' ')

        {
          dosageInstructions: toplevel_texts + code_texts,
          route: routes
        }
      end

      def dispense_request_hash
        duration = entry.dig('dispenseRequest', 'expectedSupplyDuration') || {}

        {
          refills: entry.dig('dispenseRequest', 'numberOfRepeatsAllowed'),
          duration: [duration['value'], duration['unit']].compact.join(' ')
        }
      end
    end
  end
end
