class CreateTrackVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :track_versions do |t|
      t.string :title
      t.text :waveform_data
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.jsonb :metadata

      t.timestamps
    end
  end
end
