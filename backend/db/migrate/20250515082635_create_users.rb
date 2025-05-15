class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :username
      t.string :name
      t.text :bio
      t.string :password_digest
      t.string :profile_image

      t.timestamps
    end
  end
end
