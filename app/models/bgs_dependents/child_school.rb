# frozen_string_literal: true

module BGSDependents
  class ChildSchool < Base
    attribute :last_term_school_information, Hash
    attribute :school_information, Hash
    attribute :program_information, Hash
    attribute :current_term_dates, Hash

    def initialize(proc_id, vnp_participant_id, student = nil)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      @student = student

      assign_attributes(student)
    end

    # rubocop:disable Metrics/MethodLength
    def params_for_686c
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id,
        last_term_start_dt: format_date(school_information&.dig('last_term_school_information', 'term_begin')),
        last_term_end_dt: format_date(school_information&.dig('last_term_school_information', 'date_term_ended')),
        prev_hours_per_wk_num: nil,
        prev_sessns_per_wk_num: nil,
        prev_school_nm: nil,
        prev_school_cntry_nm: nil,
        prev_school_addrs_one_txt: nil,
        prev_school_addrs_two_txt: nil,
        prev_school_addrs_three_txt: nil,
        prev_school_city_nm: nil,
        prev_school_postal_cd: nil,
        prev_school_addrs_zip_nbr: nil,
        curnt_school_nm: school_information&.dig('name'),
        curnt_school_addrs_one_txt: nil,
        curnt_school_addrs_two_txt: nil,
        curnt_school_addrs_three_txt: nil,
        curnt_school_postal_cd: nil,
        curnt_school_city_nm: nil,
        curnt_school_addrs_zip_nbr: nil,
        curnt_school_cntry_nm: nil,
        course_name_txt: nil,
        curnt_sessns_per_wk_num: nil,
        curnt_hours_per_wk_num: nil,
        school_actual_expctd_start_dt: school_information&.dig('current_term_dates', 'expected_student_start_date'),
        school_term_start_dt: format_date(school_information&.dig('current_term_dates', 'official_school_start_date')),
        gradtn_dt: format_date(school_information&.dig('current_term_dates', 'expected_graduation_date')),
        full_time_studnt_type_cd: nil,
        part_time_school_subjct_txt: nil
      }
    end
    # rubocop:enable Metrics/MethodLength

    private

    def assign_attributes(data)
      @last_term_school_information = data['last_term_school_information']
      @school_information = data['school_information']
      @program_information = data['program_information']
      @current_term_dates = data['current_term_dates']
    end
  end
end
