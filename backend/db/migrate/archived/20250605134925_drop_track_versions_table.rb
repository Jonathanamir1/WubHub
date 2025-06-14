class DropTrackVersionsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :track_versions do |t|
      t.string "title"
      t.text "waveform_data"
      t.bigint "project_id"
      t.bigint "user_id", null: false
      t.jsonb "metadata"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.text "description"
      t.bigint "workspace_id"
    end
  end
end
