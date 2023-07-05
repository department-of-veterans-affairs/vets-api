# frozen_string_literal: true

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
      claim['data']['contention_list'] = @data['contentions'] || []
      claim['data']['va_representative'] = @data['poa']
      claim['data']['development_letter_sent'] = @data['development_letter_sent']
      claim['data']['decision_letter_sent'] = @data['decision_notification_sent']
      claim['data']['documents_needed'] = @data['wwsnfy'].present?
      claim['data']['waiver5103_submitted'] = @data['filed5103_waiver_ind'] == 'Y'
      claim['data']['claim_type'] = @data['claim_status']
      claim['data']['date'] = format_bgs_date(@data&.dig('claim_dt'))
      claim['data']['min_est_claim_date'] = format_bgs_date(@data['min_est_claim_complete_dt'])
      claim['data']['max_est_claim_date'] = format_bgs_date(@data['max_est_claim_complete_dt'])
      claim['data']['claim_phase_dates'] = claim_phase_dates
      claim['data']['status_type'] = @data['claim_status_type']
      claim['data']['status'] = phase.to_s
      claim['data']['open'] = claim['data']['status'].downcase != 'complete'
      claim['data']['claim_dt'].to_s
      claim['data']['claim_complete_date'] = format_bgs_date(@data['claim_complete_dt'])
      claim['list_data'] = claim['data']

      claim
    end

    private

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
      phase_num = latest_phase_info['phase_type_change_ind'][0]
      {
        'latest_phase_type' => latest_phase_info['phase_type'],
        'phase_change_date' => format_bgs_date(latest_phase_info['phase_chngd_dt']),
        'phase_type_change_ind' => latest_phase_info['phase_type_change_ind'],
        "phase#{phase_num}_complete_date" => format_bgs_date(latest_phase_info['phase_chngd_dt'])
      }
    end
  end
end
