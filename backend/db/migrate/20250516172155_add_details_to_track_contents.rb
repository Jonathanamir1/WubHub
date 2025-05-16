class AddDetailsToTrackContents < ActiveRecord::Migration[7.1]
  def change
    add_column :track_contents, :title, :string
    add_column :track_contents, :description, :text
  end
end