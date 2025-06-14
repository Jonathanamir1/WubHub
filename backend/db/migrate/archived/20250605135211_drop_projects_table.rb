class DropProjectsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :projects do |t|
      t.string "title"
      t.text "description"
      t.bigint "workspace_id", null: false
      t.bigint "user_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
  end
end
