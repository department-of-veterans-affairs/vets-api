# frozen_string_literal: true
require_relative 'base'

module MVI
  module Responses
    # Parses the MVI Savon response for the find candidate endpoint (prpa_in201306_uv02).
    #
    # = Usage
    # The original Savon response is a complex Hash of the xml returned by MVI.
    # See specs/support/mvi/savon_response_body.json for an example of the hierarchy
    #
    # Example:
    #  response = MVI::Responses::FindCandidate.new(mvi_response)
    #
    class FindCandidate < Base
      mvi_endpoint :prpa_in201306_uv02

      SSN_ROOT_ID = '2.16.840.1.113883.4.1'
      CORRELATION_ROOT_ID = '2.16.840.1.113883.4.349'
      EDIPI_ROOT_ID = '2.16.840.1.113883.3.364'

      def initialize(response)
        super(response)
        @subject = @original_body.dig(:control_act_process, :subject)
      end

      def body
        return nil unless @subject
        patient = @subject.dig(:registration_event, :subject1, :patient)
        name = parse_name(get_patient_name(patient))
        {
          status: patient.dig(:status_code, :@code),
          given_names: name[:given],
          family_name: name[:family],
          gender: patient.dig(:patient_person, :administrative_gender_code, :@code),
          birth_date: patient.dig(:patient_person, :birth_time, :@value),
          ssn: parse_ssn(patient.dig(:patient_person, :as_other_i_ds))
        }.merge(map_correlation_ids(patient[:id]))
      end

      private

      def get_patient_name(patient)
        patient.dig(:patient_person, :name)
      end

      # name can be a hash or an array of hashes with extra unneeded details
      # given may be an array if it includes middle name
      def parse_name(name)
        name = [name] if name.is_a? Hash
        name_hash = [*name].first
        given = [*name_hash[:given]].map(&:capitalize)
        family = name_hash[:family].capitalize
        { given: given, family: family }
      rescue => e
        Rails.logger.warn "MVI::Response.parse_name failed: #{e.message}"
        { given: nil, family: nil }
      end

      # other_ids can be hash or array of hashes
      def parse_ssn(other_ids)
        other_ids = [other_ids] if other_ids.is_a? Hash
        ssn_id = other_ids.select { |id| id.dig(:id, :@root) == SSN_ROOT_ID }
        return nil if ssn_id.empty?
        ssn_id.first.dig(:id, :@extension)
      rescue => e
        Rails.logger.warn "MVI::Response.parse_ssn failed: #{e.message}"
        nil
      end

      # MVI correlation id source id relationships:
      # {source id}^{id type}^{assigning authority}^{assigning facility}^{id status}
      # NI = national identifier, PI = patient identifier
      def map_correlation_ids(ids)
        {
          icn: select_extension(ids, /^\w+\^NI\^\w+\^\w+\^\w+$/, CORRELATION_ROOT_ID),
          mhv_id: select_extension(ids, /^\w+\^PI\^200MHV\^\w+\^\w+$/, CORRELATION_ROOT_ID),
          edipi: select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^\w+$/, EDIPI_ROOT_ID),
          vba_corp_id: select_extension(ids, /^\w+\^PI\^200CORP\^USVBA\^\w+$/, CORRELATION_ROOT_ID)
        }
      end

      def select_extension(ids, pattern, root)
        extensions = ids.select do |id|
          id[:@extension] =~ pattern && id[:@root] == root
        end
        return nil if extensions.empty?
        extensions.first[:@extension]
      end
    end
  end
end
