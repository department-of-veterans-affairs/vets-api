# frozen_string_literal: true

require 'claims_api/bgs_claim_status_mapper'

module ClaimsApi
  class EvssBgsMapper
    attr_reader :evss_id, :list_data

    def initialize(claim)
      @data = add_claim(claim)
      @list_data = {}
    end

    def add_claim(claim)
      @data = {}
      @data.merge!(claim)
      @data.deep_stringify_keys
    end

    def map_and_build_object # rubocop:disable Metrics/MethodLength
      claim = EVSSClaim.new
      claim['data'] = @data

      claim['evss_id'] = @data['benefit_claim_id']
      claim['data']['contention_list'] = contentions
      claim['data']['va_representative'] = @data['poa']
      claim['data']['development_letter_sent'] = @data['development_letter_sent']
      claim['data']['decision_letter_sent'] = @data['decision_notification_sent']
      claim['data']['documents_needed'] = @data['wwsnfy'].present?

      claim['data']['waiver5103_submitted'] = @data['filed5103_waiver_ind'] == 'Y'
      claim['data']['requested_decision'] = @data['filed5103_waiver_ind'] == 'Y'

      claim['data']['claim_type'] = @data['claim_status']
      claim['data']['date'] = format_bgs_date(@data&.dig('claim_dt'))
      claim['data']['min_est_claim_date'] = format_bgs_date(@data['min_est_claim_complete_dt'])
      claim['data']['max_est_claim_date'] = format_bgs_date(@data['max_est_claim_complete_dt'])
      claim['data']['claim_phase_dates'] = get_bgs_phase_completed_dates(@data)
      claim['data']['status_type'] = @data['claim_status_type']
      claim['data']['status'] = phase.to_s
      claim['data']['open'] = claim['data']['status'].downcase != 'complete'
      claim['data']['claim_dt'].to_s
      claim['data']['claim_complete_date'] = format_bgs_date(@data['claim_complete_dt'])
      claim['list_data'] = claim['data']

      claim
    end

    private

    def contentions
      contentions = @data['contentions']&.split(/(?<=\)),/)
      return [] if contentions.nil?

      contentions
    end

    def phase
      if @data['bnft_claim_lc_status']
        case @data['bnft_claim_lc_status']
        when Array
          @data['bnft_claim_lc_status'].max_by { |d| d['phase_chngd_dt'] }['phase_type']
        when Hash
          @data['bnft_claim_lc_status']['phase_type']
        end
      elsif @data['phase_type']
        @data['phase_type']
      else
        'Claim received'
      end
    end

    def format_bgs_date(date)
      return nil if date.nil?

      d = Date.parse(date.to_s)
      d.strftime('%m/%d/%Y')
    end

    def claim_phase_dates
      return nil if @data['bnft_claim_lc_status'].nil?

      obj = [@data['bnft_claim_lc_status']].flatten
      latest_phase_info = obj.max_by { |d| d['phase_chngd_dt'] }
      phases = phases(obj)
      {
        'latest_phase_type' => latest_phase_info['phase_type'],
        'phase_change_date' => format_bgs_date(latest_phase_info['phase_chngd_dt']),
        'phase_type_change_ind' => latest_phase_info['phase_type_change_ind']
      }.merge(phases)
    end

    def phases(obj)
      events = {}
      sorted = obj.sort_by { |p| p['phase_chngd_dt'] }
      sorted.each_with_index do |phase, index|
        phase_num = phase['phase_type_change_ind'][0]
        phase_date = format_bgs_date(phase['phase_chngd_dt'])
        key = "phase#{phase_num}_complete_date"
        events.delete(key) if phase_num.to_i != index && phase_num != 'N'
        events[key] = phase_date
      end
      events
    end

    def get_bgs_phase_completed_dates(data)
      data_with_dto = [data&.dig('benefit_claim_details_dto', 'bnft_claim_lc_status')].flatten.compact
      lc_status_array =
        [data&.dig('bnft_claim_lc_status')].flatten.compact || data_with_dto

      return {} if lc_status_array.first.nil?

      max_completed_phase = lc_status_array.first['phase_type_change_ind'].chars.first
      return {} if max_completed_phase.downcase.eql?('n')

      events = {}.tap do |phase_date|
        lc_status_array.reverse.map do |phase|
          completed_phase_number = phase['phase_type_change_ind'].chars.first
          if completed_phase_number <= max_completed_phase &&
             completed_phase_number.to_i.positive?
            phase_date["phase#{completed_phase_number}CompleteDate"] = date_present(phase['phase_chngd_dt'])
          end
        end
      end.sort.reverse.to_h

      phase_dates = claim_phase_dates
      phase_dates.merge(events)
    end

    ### called from inside of format_bgs_phase_date & format_bgs_phase_chng_dates
    ### calls format_bgs_date
    def date_present(date)
      return unless date.is_a?(Date) || date.is_a?(String)

      date.present? ? format_bgs_date(date) : nil
    end
  end
end
