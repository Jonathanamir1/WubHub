class AddTagsToTrackContents < ActiveRecord::Migration[7.1]
  def change
    add_column :track_contents, :tags, :string, array: true, default: []
    add_index :track_contents, :tags, using: 'gin'
  end
end