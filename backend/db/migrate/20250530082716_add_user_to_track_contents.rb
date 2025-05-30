class AddUserToTrackContents < ActiveRecord::Migration[7.1]
  def change
    add_reference :track_contents, :user, null: false, foreign_key: true
  end
end