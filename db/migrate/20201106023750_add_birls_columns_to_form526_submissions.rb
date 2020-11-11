# frozen_string_literal: true

class AddBirlsColumnsToForm526Submissions < ActiveRecord::Migration[6.0]
  def change
    enable_extension 'pgcrypto'

    add_column(
      :form526_submissions,
      :multiple_birls,
      :boolean,
      comment: '*After* a SubmitForm526 Job fails, a lookup is done to see if the veteran has multiple ' \
               'BIRLS IDs. This field gets set to true if that is the case. If the initial submit job ' \
               'succeeds, this field will remain false whether or not the veteran has multiple BIRLS IDs ' \
               '--so this field cannot technically be used to sum all Form526 veterans that have multiple ' \
               'BIRLS. This field /can/ give us an idea of how often having multiple BIRLS IDs is a problem.'
    )
    add_column(
      :form526_submissions,
      :encrypted_birls_ids_tried,
      :string,
      comment: 'This field keeps track of the BIRLS IDs used when trying to do a SubmitForm526 Job. ' \
               'If a submit job fails, a lookup is done to retrieve all of the veteran\'s BIRLS IDs. ' \
               'If a BIRLS ID hasn\'t been used it will be swapped into the auth_headers, and the BIRLS ' \
               'ID that had just been used (when the job had failed), will be added to this array. ' \
               'To know which Form526Submissions have tried (or are trying) reattempts with a different ' \
               'BIRLS ID, search for Submissions where `multiple_birls: true`'
    )
    add_column :form526_submissions, :encrypted_birls_ids_tried_iv, :string
  end
end
