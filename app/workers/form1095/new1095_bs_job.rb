# frozen_string_literal: true

module Form1095
  class New1095BsJob
    include Sidekiq::Worker

    def bucket
      @bucket ||= Aws::S3::Resource.new(
        region: Settings.form1095_b.s3.region,
        access_key_id: Settings.form1095_b.s3.aws_access_key_id,
        secret_access_key: Settings.form1095_b.s3.aws_secret_access_key
      ).bucket(Settings.form1095_b.s3.bucket)
    end

    def get_bucket_files
      # grabs available file names from bucket
      bucket.objects({ prefix: 'MEC', delimiter: '/' }).collect(&:key)
    end

    def parse_file_name(file_name)
      return {} if file_name.blank?

      file_values = file_name.sub('.txt', '').split('_')

      year = file_values[3].to_i
      ts = file_values[-1]

      {
        is_dep_file?: file_values.include?('B'),
        isOg?: file_values.include?('O'),
        tax_year: year,
        timestamp: ts
      }
    end

    def gen_address(addr1, addr2, addr3)
      addr1.concat(' ', addr2 || '', ' ', addr3 || '').strip
    end

    def get_form_fields(data)
      fields = {}
      data.each_with_index do |field, ndx|
        next if ndx < 3

        vals = field.split('=')
        fields[vals[0].to_sym] = vals[1] || nil
      end

      fields
    end

    def get_coverage_array(form_fields)
      coverage_arr = []
      i = 1
      while i <= 13
        val = "H#{i < 10 ? '0' : ''}#{i}"
        coverage_arr.push(form_fields[val.to_sym] ? true : false)

        i += 1
      end

      coverage_arr
    end

    def produce_1095_hash(form_fields, unique_id, coverage_arr)
      {
        unique_id: unique_id,
        veteran_icn: form_fields[:A15].gsub(/\A0{6}|0{6}\z/, ''),
        form_data: {
          last_name: form_fields[:A01],
          first_name: form_fields[:A02],
          middle_name: form_fields[:A03] || '',
          last_4_ssn: form_fields[:A16] ? form_fields[:A16][-4...] : '',
          birth_date: form_fields[:N03] || '',
          address: gen_address(form_fields[:B01], form_fields[:B02], form_fields[:B03]),
          city: form_fields[:B04],
          state: form_fields[:B05] || '',
          country: form_fields[:B06],
          zip_code: form_fields[:B07] || '',
          foreign_zip: form_fields[:B08] || '',
          province: form_fields[:B10] || '',
          coverage_months: coverage_arr
        }
      }
    end

    def parse_form(form)
      data = form.split('^')

      unique_id = data[2]

      form_fields = get_form_fields(data)

      coverage_arr = get_coverage_array(form_fields)

      produce_1095_hash(form_fields, unique_id, coverage_arr)
    end

    def save_data?(form_data)
      existing_form = Form1095B.find_by(veteran_icn: form_data[:veteran_icn], tax_year: form_data[:tax_year])

      if !form_data[:is_corrected] && existing_form.present? # returns true to indicate successful entry
        Rails.logger.warn "Form for #{form_data[:tax_year]} already exists, but file is for Original 1095-B forms."
        return true
      elsif form_data[:is_corrected] && existing_form.nil?
        Rails.logger.warn "Form for year #{form_data[:tax_year]} not found, but file is for Corrected 1095-B forms."
        return true # return false here?? (or create form?) if is a correction, then it should already exist
      end

      if existing_form.nil?
        form = Form1095B.new(form_data)
        form.save
      else
        existing_form.update(form_data)
      end
    end

    def process_file?(temp_file, file_details)
      temp_file.each_line do |form|
        data = parse_form(form)

        data[:tax_year] = file_details[:tax_year]
        data[:form_data][:is_corrected] = !file_details[:isOg?]
        data[:form_data][:is_beneficiary] = file_details[:is_dep_file?]
        data[:form_data] = data[:form_data].to_json

        unique_id = data[:unique_id]
        data.delete(:unique_id)

        unless save_data?(data)
          Rails.logger.error "Failed on form with unique ID: #{unique_id}"
          return false
        end
      end

      temp_file.close
      temp_file.unlink

      true
    rescue => e
      Rails.logger.error(e.message)
      false
    end

    # downloading file to the disk and then reading that file,
    # this will allow us to read large S3 files without exhausting resources/crashing the system
    def download_and_process_file?(file_name)
      Rails.logger.info "processing file: #{file_name}"

      file_details = parse_file_name(file_name)

      return false if file_details.blank?

      # downloads S3 file into local file, allows for processing large files this way
      temp_file = Tempfile.new(file_name)

      # downloads file into temp_file
      bucket.object(file_name).get(response_target: temp_file)

      process_file?(temp_file, file_details)
    end

    def perform
      Rails.logger.info 'Checking for new 1095-B data'

      file_names = get_bucket_files
      Rails.logger.info 'No new 1095 files found' if file_names.empty?

      file_names.each do |file_name|
        if download_and_process_file?(file_name)
          Rails.logger.info "#{file_name} read successfully, deleting file from S3"
          bucket.delete_objects(delete: { objects: [{ key: file_name }] })
        else
          Rails.logger.error "failed to load 1095 data from file: #{file_name}"
        end
      end
    end
  end
end
