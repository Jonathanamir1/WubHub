class AddDescriptionToTrackVersions < ActiveRecord::Migration[7.1]
  def change
    add_column :track_versions, :description, :text
  end
end