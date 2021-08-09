# frozen_string_literal: true

module VAForms
  module UpdateFormTags
    module_function

    def run
      ActiveRecord::Base.transaction do
        # rubocop:disable Layout/LineLength
        ActiveRecord::Base.connection.execute("
        UPDATE va_forms_forms SET tags = concat(tags, ' tdiu  iu individual unemployability unemployment application increased compensation occupation hospitalized hospitalization injury service connected disability condition contention self-employment employer claim work income') WHERE lower(va_forms_forms.form_name)='21-8940';
        UPDATE va_forms_forms SET tags = concat(tags, ' coe') WHERE lower(va_forms_forms.form_name)='26-1880';
        UPDATE va_forms_forms SET tags = concat(tags, ' rfs') WHERE lower(va_forms_forms.form_name)='10-10172';
        UPDATE va_forms_forms SET tags = concat(tags, ' roi') WHERE lower(va_forms_forms.form_name) in ('va0710'  , '10-252', '10-0459', '10-259', '10-5345', '10-10116', 'va3288', '10-055', '10-0527', '10-0525a', '10-0493');
        UPDATE va_forms_forms SET tags = concat(tags, ' poi') WHERE lower(va_forms_forms.form_name)='10-0137';
        UPDATE va_forms_forms SET tags = concat(tags, ' itf') WHERE lower(va_forms_forms.form_name)='21-0966';
        UPDATE va_forms_forms SET tags = concat(tags, ' dic') WHERE lower(va_forms_forms.form_name)='21p-535';
        UPDATE va_forms_forms SET tags = concat(tags, ' rn') WHERE lower(va_forms_forms.form_name) in ('10-2850a', '10-0430');
        UPDATE va_forms_forms SET tags = concat(tags, ' headstone') WHERE lower(va_forms_forms.form_name) in ('21p-530', 'va40-10007' , '21p-10196');
        UPDATE va_forms_forms SET tags = concat(tags, ' vehicle car') WHERE lower(va_forms_forms.form_name) in ('10-1394', '10-2511');
        UPDATE va_forms_forms SET tags = concat(tags, ' caretaker') WHERE lower(va_forms_forms.form_name)='10-10cg';
        UPDATE va_forms_forms SET tags = concat(tags, ' dea') WHERE lower(va_forms_forms.form_name)='22-5490';
        UPDATE va_forms_forms SET tags = concat(tags, ' hippa') WHERE lower(va_forms_forms.form_name) in ('10-252', '10-10163', '10-10164', '10-0527', '10-10116');
        UPDATE va_forms_forms SET tags = concat(tags, ' pcafc') WHERE lower(va_forms_forms.form_name)='10-10cg';
        UPDATE va_forms_forms SET tags = concat(tags, ' vr vrne') WHERE lower(va_forms_forms.form_name) in ('28-0588', '28-1900');
      ")
        # rubocop:enable Layout/LineLength
      end
    end
  end
end

namespace :va_forms do
  task update_form_tags: :environment do
    VAForms::UpdateFormTags.run
  end
end
