# frozen_string_literal: true

module BGSDependents
  class ChildSchool < Base
    attribute :last_term_school_information, Hash
    attribute :school_information, Hash
    attribute :program_information, Hash
    attribute :current_term_dates, Hash

    def initialize(dependents_application, proc_id, vnp_participant_id)
      @proc_id = proc_id
      @vnp_participant_id = vnp_participant_id
      self.attributes = dependents_application
    end

    # rubocop:disable Metrics/MethodLength
    def params_for_686c
      {
        vnp_proc_id: @proc_id,
        vnp_ptcpnt_id: @vnp_participant_id,
        last_term_start_dt: format_date(last_term_school_information&.dig('term_begin')),
        last_term_end_dt: format_date(last_term_school_information&.dig('date_term_ended')),
        prev_hours_per_wk_num: last_term_school_information&.dig('hours_per_week'),
        prev_sessns_per_wk_num: last_term_school_information&.dig('classes_per_week'),
        prev_school_nm: last_term_school_information&.dig('name'),
        prev_school_cntry_nm: last_term_school_information&.dig('address', 'country_name'),
        prev_school_addrs_one_txt: last_term_school_information&.dig('address', 'address_line1'),
        prev_school_addrs_two_txt: last_term_school_information&.dig('address', 'address_line2'),
        prev_school_addrs_three_txt: last_term_school_information&.dig('address', 'address_line3'),
        prev_school_city_nm: last_term_school_information&.dig('address', 'city'),
        prev_school_postal_cd: last_term_school_information&.dig('address', 'state_code'),
        prev_school_addrs_zip_nbr: last_term_school_information&.dig('address', 'zip_code'),
        curnt_school_nm: school_information&.dig('name'),
        curnt_school_addrs_one_txt: program_information&.dig('student_is_enrolled_full_time') ? 'AttendingContinuously=Y' : nil,
        curnt_school_addrs_two_txt: current_term_dates&.dig('is_school_accredited') ? 'Accredited=Y' : nil,
        curnt_school_addrs_three_txt: school_information&.dig('address', 'address_line3'),
        curnt_school_postal_cd: school_information&.dig('address', 'state_code'),
        curnt_school_city_nm: school_information&.dig('address', 'city'),
        curnt_school_addrs_zip_nbr: school_information&.dig('address', 'zip_code'),
        curnt_school_cntry_nm: school_information&.dig('address', 'country_name'),
        course_name_txt: school_information&.dig('training_program'),
        curnt_sessns_per_wk_num: program_information&.dig('classes_per_week'),
        curnt_hours_per_wk_num: program_information&.dig('hours_per_week'),
        school_actual_expctd_start_dt: current_term_dates&.dig('official_school_start_date'),
        school_term_start_dt: format_date(current_term_dates&.dig('expected_student_start_date')),
        gradtn_dt: format_date(current_term_dates&.dig('expected_graduation_date')),
        full_time_studnt_type_cd: school_information&.dig('school_type'),
        part_time_school_subjct_txt: program_information&.dig('course_of_study')
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
