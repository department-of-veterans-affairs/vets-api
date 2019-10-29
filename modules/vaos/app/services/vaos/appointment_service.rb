# frozen_string_literal: true

module VAOS
  class AppointmentService < Common::Client::Base
    include Common::Client::Monitoring

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    def get_va_appointments(user, start_date, end_date, per_page = 0, page = nil)
      with_monitoring do
        url = get_va_appointments_url(user.icn, start_date, end_date, per_page, page)
        response = perform(:get, url, headers(user))
        {
          data: sanitize_va_appointments(response.body),
          meta: pagination(per_page, page)
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    def get_cc_appointments(user, start_date, end_date, per_page = 0, page = nil)
      with_monitoring do
        url = get_cc_appointments_url(user.icn, start_date, end_date, per_page, page)
        response = perform(:get, url, headers(user))
        {
          data: sanitize_cc_appointments(response.body),
          meta: pagination(per_page, page)
        }
      end
    rescue Common::Client::Errors::ClientError => e
      raise_backend_exception('VAOS_502', self.class, e)
    end

    private

    def sanitize_va_appointments(json_hash)
      json_hash.dig(:data, :appointment_list).map do |a|
        {
          id: Digest::MD5.hexdigest(a[:start_date] + a[:patient_icn]), # have to create our own id.
          type: 'va_appointments',
          attributes: Hash[sanitize_array_values(a)]
        }
      end
    end

    def sanitize_cc_appointments(json_hash)
      json_hash[:booked_appointment_collections].first[:booked_cc_appointments].map do |a|
        {
          id: a[:appointment_request_id],
          type: 'cc_appointments',
          attributes: a.except(:patient_identifier) # this contains ICN which we don't want to surface in FE
        }
      end
    end

    def sanitize_array_values(appointment)
      appointment.except(:patient_icn)        # remove ICN
                 .reverse_merge(
                   vvs_appointments: [],
                   vds_appointments: [],
                   clinic_friendly_name: nil
                 )                            # make array consistent
                 .map do |k, v|
        case k
        when :vds_appointments
          [k, v.map do |vds|
            vds.reverse_merge(booking_note: nil, appointment_length: nil) # make array consistent
               .except(:patient_id)                                       # remove patient identifiers
            end]
        when :vvs_appointments
          [k, v.map do |vvs|
                vvs.merge( # flatten the structure of patients and providers and remove patient identifiers
                  patients: vvs[:patients][:patient].map { |s| s.except(:id) },
                  providers: vvs[:providers][:provider].map { |s| s.except(:id) }
                )
              end]
        else
          [k, v]
        end
      end
    end

    # TODO: need underlying APIs to support pagination consistently
    def pagination(per_page, page)
      {
        pagination: {
          current_page: page || 1,
          per_page: per_page,
          total_pages: 0, # underlying api doesn't provide this; how do you build a pagination UI without it?
          total_entries: 0 # underlying api doesn't provide this.
        }
      }
    end

    def get_va_appointments_url(icn, start_date, end_date, per_page, page)
      url = "/appointments/v1/patients/#{icn}/appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false"
      per_page.positive? ? (url + "&pageSize=#{per_page}&page=#{page}") : (url + "&pageSize=#{per_page}")
    end

    def get_cc_appointments_url(icn, start_date, end_date, per_page, page)
      url = '/VeteranAppointmentRequestService/v4/rest/direct-scheduling/'\
          "patient/ICN/#{icn}/booked-cc-appointments"\
          "?startDate=#{date_format(start_date)}&endDate=#{date_format(end_date)}&useCache=false"
      per_page.positive? ? (url + "&pageSize=#{per_page}&page=#{page}") : (url + "&pageSize=#{per_page}")
    end

    def date_format(date)
      date.strftime('%Y-%m-%dT%TZ')
    end

    def headers(user)
      { 'Referer' => 'https://api.va.gov', 'X-VAMF-JWT' => VAOS::JWT.new(user).token }
    end
  end
end
