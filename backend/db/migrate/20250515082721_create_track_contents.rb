class CreateTrackContents < ActiveRecord::Migration[7.1]
  def change
    create_table :track_contents do |t|
      t.references :track_version, null: false, foreign_key: true
      t.string :content_type
      t.text :text_content
      t.jsonb :metadata

      t.timestamps
    end
  end
end
