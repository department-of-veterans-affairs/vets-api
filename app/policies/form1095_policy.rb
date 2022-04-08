# frozen_string_literal: true

Form1095Policy = Struct.new(:user, :form1095) do
  def access?
    user.present? && user.loa3? && user.icn.present?
  end
end
